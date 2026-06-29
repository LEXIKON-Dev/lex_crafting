LEXCrafting = LEXCrafting or {}
LEXCrafting.ActiveCraftTimers = LEXCrafting.ActiveCraftTimers or {}

function LEXCrafting.HandleOpenRequest(source, pointId)
    LEXCrafting.EnsureConfigLoaded()

    local point = LEXCrafting.GetPointById(pointId)
    if not point then
        LEXCrafting.Notify(source, _U('point_not_found'))
        return
    end

    if not LEXCrafting.HasJobAccess(source, point) then
        LEXCrafting.Notify(source, _U('wrong_job'))
        return
    end

    if LEXCrafting.PlayerDistanceToPoint(source, point) > point.maxCraftRadius then
        LEXCrafting.Notify(source, _U('too_far'))
        return
    end

    local payload = LEXCrafting.BuildOpenPayload(source, pointId)
    if not payload then
        LEXCrafting.Notify(source, _U('point_not_found'))
        return
    end

    local recipeCount = 0
    for _, cat in ipairs(LEXCrafting.AsArray(payload.categories)) do
        recipeCount = recipeCount + #LEXCrafting.AsArray(cat.recipes)
    end

    if recipeCount == 0 then
        LEXCrafting.Notify(source, _U('no_recipes'))
    end

    TriggerClientEvent(
        'lex_crafting:openUi',
        source,
        LEXCrafting.CloneForNet(payload),
        LEXCrafting.CloneForNet(LEXCrafting.BuildQueuePayload(source))
    )

    CreateThread(function()
        Wait(150)
        LEXCrafting.SyncInventoryToClient(source, pointId)
    end)
end

function LEXCrafting.CountActiveQueue(identifier)
    local result = MySQL.scalar.await(
        'SELECT COUNT(*) FROM lex_crafting_player_queue WHERE identifier = ? AND status IN (?, ?)',
        { identifier, 'crafting', 'queued' }
    )
    return result or 0
end

function LEXCrafting.RemoveIngredients(source, recipe)
    for _, ing in ipairs(recipe.ingredients) do
        local count = LEXCrafting.GetItemCount(source, ing.item)
        if count < ing.amount then
            return false
        end
    end

    for _, ing in ipairs(recipe.ingredients) do
        exports.ox_inventory:RemoveItem(source, ing.item, ing.amount)
    end
    return true
end

function LEXCrafting.PromoteNextCraft(identifier)
    local nextRow = MySQL.single.await(
        'SELECT id FROM lex_crafting_player_queue WHERE identifier = ? AND status = ? ORDER BY id ASC LIMIT 1',
        { identifier, 'queued' }
    )
    if nextRow then
        MySQL.update.await(
            'UPDATE lex_crafting_player_queue SET status = ?, started_at = NOW() WHERE id = ?',
            { 'crafting', nextRow.id }
        )
        LEXCrafting.StartCraftTimer(nextRow.id)
    end
end

function LEXCrafting.StartCraftTimer(queueId)
    if LEXCrafting.ActiveCraftTimers[queueId] then return end
    LEXCrafting.ActiveCraftTimers[queueId] = true

    CreateThread(function()
        local row = MySQL.single.await('SELECT * FROM lex_crafting_player_queue WHERE id = ?', { queueId })
        if not row or row.status ~= 'crafting' then
            LEXCrafting.ActiveCraftTimers[queueId] = nil
            return
        end

        local timeLeft = row.time_left
        while timeLeft > 0 do
            Wait(1000)
            timeLeft = timeLeft - 1
            MySQL.update.await('UPDATE lex_crafting_player_queue SET time_left = ? WHERE id = ?', { timeLeft, queueId })
        end

        local current = MySQL.single.await('SELECT * FROM lex_crafting_player_queue WHERE id = ?', { queueId })
        if not current or current.status ~= 'crafting' then
            LEXCrafting.ActiveCraftTimers[queueId] = nil
            return
        end

        local success = math.random(100) <= current.success_rate
        local newStatus = success and 'done' or 'failed'
        MySQL.update.await('UPDATE lex_crafting_player_queue SET status = ?, time_left = 0 WHERE id = ?', {
            newStatus,
            queueId,
        })

        local src = LEXCrafting.GetSourceByIdentifier(current.identifier)
        if src then
            LEXCrafting.SyncQueueToClient(src)
            LEXCrafting.Notify(src, success and _U('craft_success') or _U('craft_failed'))
        end

        LEXCrafting.PromoteNextCraft(current.identifier)
        if src then LEXCrafting.SyncQueueToClient(src) end
        LEXCrafting.ActiveCraftTimers[queueId] = nil
    end)
end

function LEXCrafting.GetSourceByIdentifier(identifier)
    local players = LEXCrafting.GetESX().GetExtendedPlayers()
    for _, xPlayer in pairs(players) do
        if xPlayer.identifier == identifier then
            return xPlayer.source
        end
    end
    return nil
end

function LEXCrafting.HandleCraft(source, data)
    local pointId = data and data.pointId
    local recipeId = data and data.recipeId
    local amount = tonumber(data and data.amount) or 1

    local point = LEXCrafting.GetPointById(pointId)
    local recipe = LEXCrafting.GetRecipeById(recipeId)
    local identifier = LEXCrafting.GetIdentifier(source)

    if not point or not recipe or not identifier then
        LEXCrafting.Notify(source, _U('recipe_not_found'))
        return
    end

    if not LEXCrafting.HasJobAccess(source, point) then
        LEXCrafting.Notify(source, _U('wrong_job'))
        return
    end

    if not LEXCrafting.HasRecipeJobAccess(source, recipe) then
        LEXCrafting.Notify(source, _U('wrong_job'))
        return
    end

    if LEXCrafting.PlayerDistanceToPoint(source, point) > point.maxCraftRadius then
        LEXCrafting.Notify(source, _U('too_far'))
        return
    end

    local maxQueue = LEXCrafting.Settings.maxQueue or 5
    local active = LEXCrafting.CountActiveQueue(identifier)
    local available = maxQueue - active
    if available <= 0 then
        LEXCrafting.Notify(source, _U('queue_full'))
        return
    end

    local toAdd = math.min(amount, available)
    local added = 0

    for _ = 1, toAdd do
        if not LEXCrafting.RemoveIngredients(source, recipe) then
            LEXCrafting.Notify(source, _U('missing_items'))
            break
        end

        local hasCrafting = MySQL.scalar.await(
            'SELECT COUNT(*) FROM lex_crafting_player_queue WHERE identifier = ? AND status = ?',
            { identifier, 'crafting' }
        ) or 0

        local status = hasCrafting > 0 and 'queued' or 'crafting'
        local insertId = MySQL.insert.await(
            [[INSERT INTO lex_crafting_player_queue
              (identifier, point_id, recipe_id, item, label, yield_amount, status, time_left, total_time, success_rate)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            {
                identifier,
                pointId,
                recipe.id,
                recipe.item,
                recipe.label,
                recipe.yield,
                status,
                recipe.craftTime,
                recipe.craftTime,
                recipe.successRate,
            }
        )

        if status == 'crafting' then
            LEXCrafting.StartCraftTimer(insertId)
        end
        added = added + 1
    end

    if added > 0 then
        LEXCrafting.Notify(source, _U('craft_started'))
        LEXCrafting.SyncQueueToClient(source)
        LEXCrafting.SyncInventoryToClient(source, pointId)
    end
end

function LEXCrafting.HandleClaimAll(source, data)
    local identifier = LEXCrafting.GetIdentifier(source)
    if not identifier then return end

    local rows = MySQL.query.await(
        'SELECT * FROM lex_crafting_player_queue WHERE identifier = ? AND status = ?',
        { identifier, 'done' }
    ) or {}

    if #rows == 0 then
        LEXCrafting.Notify(source, _U('nothing_to_claim'))
        return
    end

    local claimed = 0
    for _, row in ipairs(rows) do
        local canAdd = exports.ox_inventory:CanCarryItem(source, row.item, row.yield_amount)
        if canAdd then
            exports.ox_inventory:AddItem(source, row.item, row.yield_amount)
            MySQL.update.await('UPDATE lex_crafting_player_queue SET status = ? WHERE id = ?', { 'claimed', row.id })
            claimed = claimed + 1
        else
            LEXCrafting.Notify(source, _U('inventory_full'))
            break
        end
    end

    if claimed > 0 then
        LEXCrafting.Notify(source, _U('claimed_items'))
        LEXCrafting.SyncQueueToClient(source)
    end
end

function LEXCrafting.HandleCancelCraft(source, data)
    local identifier = LEXCrafting.GetIdentifier(source)
    local queueId = tonumber(data and data.queueId)
    if not identifier or not queueId then return end

    local row = MySQL.single.await(
        'SELECT * FROM lex_crafting_player_queue WHERE id = ? AND identifier = ? AND status = ?',
        { queueId, identifier, 'crafting' }
    )
    if not row then return end

    MySQL.update.await('DELETE FROM lex_crafting_player_queue WHERE id = ?', { queueId })
    LEXCrafting.PromoteNextCraft(identifier)
    LEXCrafting.SyncQueueToClient(source)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        local rows = MySQL.query.await(
            'SELECT id FROM lex_crafting_player_queue WHERE status = ?',
            { 'crafting' }
        ) or {}
        for _, row in ipairs(rows) do
            LEXCrafting.StartCraftTimer(row.id)
        end
    end)
end)
