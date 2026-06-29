LEXCrafting = LEXCrafting or {}

function LEXCrafting.DbBool(value, default)
    if value == nil then return default == true end
    if value == true or value == false then return value end
    if type(value) == 'number' then return value ~= 0 end
    if type(value) == 'string' then
        local v = value:lower()
        return v == '1' or v == 'true'
    end
    return default == true
end

function LEXCrafting.ToDbFlag(value, default)
    return LEXCrafting.DbBool(value, default) and 1 or 0
end

function LEXCrafting.AsArray(value)
    if type(value) ~= 'table' then return {} end

    local result = {}
    local numericKeys = {}

    for key, entry in pairs(value) do
        if type(key) == 'number' and key >= 1 and key % 1 == 0 then
            numericKeys[#numericKeys + 1] = key
        end
    end

    if #numericKeys > 0 then
        table.sort(numericKeys)
        for _, key in ipairs(numericKeys) do
            result[#result + 1] = value[key]
        end
        return result
    end

    for key, entry in pairs(value) do
        if type(key) == 'string' then
            local index = tonumber(key)
            if index and index >= 1 and index % 1 == 0 then
                numericKeys[#numericKeys + 1] = index
            end
        end
    end

    if #numericKeys > 0 then
        table.sort(numericKeys)
        for _, index in ipairs(numericKeys) do
            local entry = value[index] or value[tostring(index)]
            if entry ~= nil then
                result[#result + 1] = entry
            end
        end
        return result
    end

    for _, entry in pairs(value) do
        result[#result + 1] = entry
    end

    return result
end

function LEXCrafting.CloneForNet(data)
    if type(data) ~= 'table' then return data end
    local ok, result = pcall(json.decode, json.encode(data))
    return ok and result or data
end

function LEXCrafting.RebuildIndexes()
    LEXCrafting.RecipeById = {}
    LEXCrafting.PointById = {}

    if not LEXCrafting.Config then return end

    for _, recipe in ipairs(LEXCrafting.AsArray(LEXCrafting.Config.recipes)) do
        if recipe.id then
            LEXCrafting.RecipeById[recipe.id] = recipe
        end
    end

    for _, point in ipairs(LEXCrafting.AsArray(LEXCrafting.Config.points)) do
        if point.id then
            LEXCrafting.PointById[point.id] = point
        end
    end
end

function LEXCrafting.NormalizeSettings(settings)
    settings = settings or {}
    return {
        maxQueue = settings.maxQueue or 5,
        useCategories = LEXCrafting.DbBool(settings.useCategories, true),
        hideMinimap = LEXCrafting.DbBool(settings.hideMinimap, true),
        locale = settings.locale or 'de',
        defaultOpenKey = settings.defaultOpenKey or 'E',
    }
end

function LEXCrafting.ApplyConfigFromSavePayload(config)
    local recipes = LEXCrafting.AsArray(config.recipes)
    local points = LEXCrafting.AsArray(config.points)
    LEXCrafting.Settings = LEXCrafting.NormalizeSettings(config.settings)
    LEXCrafting.Config = {
        recipes = recipes,
        points = points,
        settings = LEXCrafting.Settings,
    }
    LEXCrafting.RebuildIndexes()
    return LEXCrafting.Config
end

function LEXCrafting.AddBatchInserts(queries, tableName, columns, rows, batchSize)
    if #rows == 0 then return end

    batchSize = batchSize or Config.SaveBatchSize or 200
    local columnCount = #columns
    local columnList = table.concat(columns, ', ')
    local rowPlaceholder = '(' .. string.rep('?,', columnCount - 1) .. '?)'

    for offset = 1, #rows, batchSize do
        local placeholders = {}
        local values = {}
        local limit = math.min(offset + batchSize - 1, #rows)
        local writeIndex = 0

        for index = offset, limit do
            local row = rows[index]
            placeholders[#placeholders + 1] = rowPlaceholder

            for colIndex = 1, columnCount do
                local cell = row[colIndex]
                if cell == nil then
                    error(('[lex_crafting] Batch insert %s: fehlender Wert in Zeile %d, Spalte %s'):format(
                        tableName,
                        index,
                        columns[colIndex] or tostring(colIndex)
                    ))
                end
                writeIndex = writeIndex + 1
                values[writeIndex] = cell
            end
        end

        local expected = #placeholders * columnCount
        if writeIndex ~= expected then
            error(('[lex_crafting] Batch insert %s: Wert-Anzahl %d, erwartet %d'):format(
                tableName,
                writeIndex,
                expected
            ))
        end

        queries[#queries + 1] = {
            query = ('INSERT INTO %s (%s) VALUES %s'):format(
                tableName,
                columnList,
                table.concat(placeholders, ',')
            ),
            values = values,
        }
    end
end

function LEXCrafting.ConfigSyncBps()
    return Config.ConfigSyncBps or 1000000
end

function LEXCrafting.BroadcastConfigAsync(excludeSource, netConfig)
    CreateThread(function()
        netConfig = netConfig or LEXCrafting.CloneForNet(LEXCrafting.Config)
        local settings = LEXCrafting.Settings
        local bps = LEXCrafting.ConfigSyncBps()

        for _, playerId in ipairs(GetPlayers()) do
            local id = tonumber(playerId)
            if id and id ~= excludeSource then
                TriggerLatentClientEvent('lex_crafting:receiveConfig', id, bps, netConfig, settings)
            end
        end
    end)
end

function LEXCrafting.SendConfigToPlayer(source, includeCreatorReload, netConfig)
    netConfig = netConfig or LEXCrafting.CloneForNet(LEXCrafting.Config)
    local bps = LEXCrafting.ConfigSyncBps()

    if includeCreatorReload then
        TriggerLatentClientEvent('lex_crafting:loadCreatorConfig', source, bps, netConfig)
    end

    TriggerLatentClientEvent('lex_crafting:receiveConfig', source, bps, netConfig, LEXCrafting.Settings)
end

function LEXCrafting.EnsureConfigLoaded()
    if LEXCrafting.Config and LEXCrafting.Settings then return end
    LEXCrafting.LoadAllConfigAwait()
end

function LEXCrafting.ApplyConfigFromDb()
    local row = MySQL.single.await('SELECT * FROM lex_crafting_settings WHERE id = 1', {})
    if not row then
        LEXCrafting.Settings = LEXCrafting.NormalizeSettings(nil)
    else
        LEXCrafting.Settings = LEXCrafting.NormalizeSettings({
            maxQueue = row.max_queue,
            useCategories = row.use_categories,
            hideMinimap = row.hide_minimap,
            locale = row.locale,
            defaultOpenKey = row.default_open_key,
        })
    end

    local recipesP = promise.new()
    local ingredientsP = promise.new()
    local pointsP = promise.new()
    local jobsP = promise.new()
    local recipeJobsP = promise.new()
    local categoriesP = promise.new()
    local catRecipesP = promise.new()

    MySQL.query('SELECT * FROM lex_crafting_recipes', {}, function(result)
        recipesP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_recipe_ingredients', {}, function(result)
        ingredientsP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_points', {}, function(result)
        pointsP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_point_jobs', {}, function(result)
        jobsP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_recipe_jobs', {}, function(result)
        recipeJobsP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_point_categories', {}, function(result)
        categoriesP:resolve(result or {})
    end)
    MySQL.query('SELECT * FROM lex_crafting_category_recipes', {}, function(result)
        catRecipesP:resolve(result or {})
    end)

    local recipes = Citizen.Await(recipesP)
    local ingredients = Citizen.Await(ingredientsP)
    local points = Citizen.Await(pointsP)
    local jobs = Citizen.Await(jobsP)
    local recipeJobs = Citizen.Await(recipeJobsP)
    local categories = Citizen.Await(categoriesP)
    local catRecipes = Citizen.Await(catRecipesP)

    local ingByRecipe = {}
    for _, ing in ipairs(ingredients) do
        ingByRecipe[ing.recipe_id] = ingByRecipe[ing.recipe_id] or {}
        table.insert(ingByRecipe[ing.recipe_id], {
            item = ing.item,
            label = ing.label,
            amount = ing.amount,
        })
    end

    local jobsByRecipe = {}
    for _, j in ipairs(recipeJobs) do
        jobsByRecipe[j.recipe_id] = jobsByRecipe[j.recipe_id] or {}
        table.insert(jobsByRecipe[j.recipe_id], {
            job = j.job,
            minGrade = j.min_grade,
        })
    end

    local recipeMap = {}
    for _, r in ipairs(recipes) do
        recipeMap[r.id] = {
            id = r.id,
            item = r.item,
            label = r.label,
            category = r.category,
            craftTime = r.craft_time,
            successRate = r.success_rate,
            yield = r.yield_amount,
            enabled = LEXCrafting.DbBool(r.enabled, true),
            ingredients = ingByRecipe[r.id] or {},
            jobs = jobsByRecipe[r.id] or {},
        }
    end

    local jobsByPoint = {}
    for _, j in ipairs(jobs) do
        jobsByPoint[j.point_id] = jobsByPoint[j.point_id] or {}
        table.insert(jobsByPoint[j.point_id], {
            job = j.job,
            minGrade = j.min_grade,
        })
    end

    local recipesByCategory = {}
    for _, cr in ipairs(catRecipes) do
        recipesByCategory[cr.category_id] = recipesByCategory[cr.category_id] or {}
        table.insert(recipesByCategory[cr.category_id], cr.recipe_id)
    end

    local catsByPoint = {}
    for _, c in ipairs(categories) do
        catsByPoint[c.point_id] = catsByPoint[c.point_id] or {}
        table.insert(catsByPoint[c.point_id], {
            id = c.id,
            label = c.label,
            sortOrder = c.sort_order,
            recipeIds = recipesByCategory[c.id] or {},
        })
    end

    local configPoints = {}
    for _, p in ipairs(points) do
        table.insert(configPoints, {
            id = p.id,
            name = p.name,
            enabled = LEXCrafting.DbBool(p.enabled, true),
            interactionType = p.interaction_type,
            openKey = p.open_key,
            coords = {
                x = p.coord_x,
                y = p.coord_y,
                z = p.coord_z,
                heading = p.heading,
            },
            model = p.model,
            interactionRadius = p.interaction_radius,
            maxCraftRadius = p.max_craft_radius,
            jobs = jobsByPoint[p.id] or {},
            categories = catsByPoint[p.id] or {},
            blip = {
                enabled = LEXCrafting.DbBool(p.blip_enabled, false),
                sprite = p.blip_sprite,
                color = p.blip_color,
                scale = p.blip_scale,
                label = p.blip_label,
                showDistance = p.blip_show_distance,
            },
            marker = {
                enabled = LEXCrafting.DbBool(p.marker_enabled, true),
                type = p.marker_type,
                color = {
                    r = p.marker_color_r,
                    g = p.marker_color_g,
                    b = p.marker_color_b,
                    a = p.marker_color_a,
                },
                size = p.marker_size,
            },
        })
    end

    local configRecipes = {}
    for _, r in pairs(recipeMap) do
        table.insert(configRecipes, r)
    end

    LEXCrafting.Config = {
        recipes = configRecipes,
        points = configPoints,
        settings = LEXCrafting.Settings,
    }

    LEXCrafting.RebuildIndexes()
    return LEXCrafting.Config
end

function LEXCrafting.LoadAllConfigAwait(broadcast)
    LEXCrafting.ApplyConfigFromDb()
    if broadcast ~= false then
        LEXCrafting.BroadcastConfigAsync()
    end
end

function LEXCrafting.LoadSettings(cb)
    if cb then cb() end
end

function LEXCrafting.LoadAllConfig(cb)
    CreateThread(function()
        LEXCrafting.LoadAllConfigAwait()
        if cb then cb() end
    end)
end

function LEXCrafting.GetPointById(pointId)
    if LEXCrafting.PointById and LEXCrafting.PointById[pointId] then
        return LEXCrafting.PointById[pointId]
    end
    if not LEXCrafting.Config then return nil end
    for _, point in ipairs(LEXCrafting.AsArray(LEXCrafting.Config.points)) do
        if point.id == pointId then return point end
    end
    return nil
end

function LEXCrafting.GetRecipeById(recipeId)
    if LEXCrafting.RecipeById and LEXCrafting.RecipeById[recipeId] then
        return LEXCrafting.RecipeById[recipeId]
    end
    if not LEXCrafting.Config then return nil end
    for _, recipe in ipairs(LEXCrafting.AsArray(LEXCrafting.Config.recipes)) do
        if recipe.id == recipeId then return recipe end
    end
    return nil
end

function LEXCrafting.GetItemCount(source, item)
    if not item or item == '' then return 0 end

    local itemName = tostring(item)
    local itemLower = string.lower(itemName)
    local count = nil

    local function pickCount(result)
        if type(result) == 'number' then return result end
        if type(result) ~= 'table' then return nil end
        if type(result[itemLower]) == 'number' then return result[itemLower] end
        if type(result[itemName]) == 'number' then return result[itemName] end
        if type(result.count) == 'number' then return result.count end
        local total = 0
        for _, v in pairs(result) do
            if type(v) == 'number' then
                total = total + v
            elseif type(v) == 'table' and type(v.count) == 'number' then
                total = total + v.count
            end
        end
        return total > 0 and total or nil
    end

    local ok, result = pcall(function()
        return exports.ox_inventory:GetItemCount(source, itemLower)
    end)
    if ok then count = pickCount(result) end

    if not count or count == 0 then
        ok, result = pcall(function()
            return exports.ox_inventory:GetItemCount(source, itemName)
        end)
        if ok then count = pickCount(result) end
    end

    if not count or count == 0 then
        ok, result = pcall(function()
            return exports.ox_inventory:Search(source, 'count', itemLower)
        end)
        if ok then count = pickCount(result) end
    end

    if not count or count == 0 then
        ok, result = pcall(function()
            return exports.ox_inventory:Search(source, 'count', itemName)
        end)
        if ok then count = pickCount(result) end
    end

    if not count or count == 0 then
        ok, result = pcall(function()
            return exports.ox_inventory:Search(source, 'slots', itemLower)
        end)
        if ok then count = pickCount(result) end
    end

    return tonumber(count) or 0
end

function LEXCrafting.GetIdentifier(source)
    local xPlayer = LEXCrafting.GetESX().GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier or nil
end

function LEXCrafting.IsAdmin(source)
    if Config.AllowCreatorForAll then return true end

    local xPlayer = LEXCrafting.GetESX().GetPlayerFromId(source)
    if not xPlayer then return false end

    local group = xPlayer.getGroup and xPlayer.getGroup() or xPlayer.group
    if type(group) == 'table' then
        group = group.name or group.group
    end
    if not group then return false end

    for _, g in ipairs(Config.AdminGroups or {}) do
        if group == g then return true end
    end
    return false
end

function LEXCrafting.HasJobAccess(source, point)
    local jobs = LEXCrafting.AsArray(point.jobs)
    if #jobs == 0 then return true end
    return LEXCrafting.PlayerMatchesJobRestrictions(source, jobs)
end

function LEXCrafting.PlayerMatchesJobRestrictions(source, jobs)
    local xPlayer = LEXCrafting.GetESX().GetPlayerFromId(source)
    if not xPlayer then return false end
    local playerJob = xPlayer.getJob()
    for _, restriction in ipairs(LEXCrafting.AsArray(jobs)) do
        if restriction.job and restriction.job ~= '' and playerJob.name == restriction.job and playerJob.grade >= (restriction.minGrade or 0) then
            return true
        end
    end
    return false
end

function LEXCrafting.HasRecipeJobAccess(source, recipe)
    local jobs = LEXCrafting.AsArray(recipe and recipe.jobs)
    if #jobs == 0 then return true end
    return LEXCrafting.PlayerMatchesJobRestrictions(source, jobs)
end

function LEXCrafting.PlayerDistanceToPoint(source, point)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local p = point.coords
    return #(coords - vector3(p.x, p.y, p.z))
end

function LEXCrafting.BuildRecipeEntry(source, recipe)
    local ingredients = {}
    for _, ing in ipairs(LEXCrafting.AsArray(recipe.ingredients)) do
        local ownedCount = LEXCrafting.GetItemCount(source, ing.item)
        if type(ownedCount) ~= 'number' then ownedCount = 0 end
        table.insert(ingredients, {
            item = ing.item,
            label = ing.label,
            amount = ing.amount,
            owned = ownedCount,
        })
    end

    return {
        id = recipe.id,
        item = recipe.item,
        name = recipe.label,
        category = recipe.category,
        description = '',
        time = recipe.craftTime,
        successRate = recipe.successRate,
        yield = recipe.yield,
        ingredients = ingredients,
    }
end

function LEXCrafting.BuildOpenPayload(source, pointId)
    local point = LEXCrafting.GetPointById(pointId)
    if not point or not point.enabled then return nil end

    local recipeMap = LEXCrafting.RecipeById or {}

    local categories = {}
    local sortedCategories = LEXCrafting.AsArray(point.categories)
    table.sort(sortedCategories, function(a, b) return (a.sortOrder or 0) < (b.sortOrder or 0) end)

    for _, cat in ipairs(sortedCategories) do
        local catRecipes = {}
        for _, recipeId in ipairs(LEXCrafting.AsArray(cat.recipeIds)) do
            local recipe = recipeMap[recipeId]
            if recipe and recipe.enabled and LEXCrafting.HasRecipeJobAccess(source, recipe) then
                table.insert(catRecipes, LEXCrafting.BuildRecipeEntry(source, recipe))
            end
        end
        if #catRecipes > 0 then
            table.insert(categories, {
                id = cat.id,
                label = cat.label,
                recipes = catRecipes,
            })
        end
    end

    local recipeCount = 0
    for _, cat in ipairs(categories) do
        recipeCount = recipeCount + #LEXCrafting.AsArray(cat.recipes)
    end

    if recipeCount == 0 then
        local fallbackRecipes = {}
        for _, recipe in ipairs(LEXCrafting.AsArray(LEXCrafting.Config.recipes)) do
            if recipe.enabled and LEXCrafting.HasRecipeJobAccess(source, recipe) then
                table.insert(fallbackRecipes, LEXCrafting.BuildRecipeEntry(source, recipe))
            end
        end
        if #fallbackRecipes > 0 then
            categories = {
                {
                    id = 'cat_all',
                    label = 'Alles',
                    recipes = fallbackRecipes,
                },
            }
        end
    end

    return {
        workbenchName = point.name,
        pointId = point.id,
        maxQueue = LEXCrafting.Settings.maxQueue or 5,
        categories = categories,
    }
end

function LEXCrafting.BuildQueuePayload(source)
    local identifier = LEXCrafting.GetIdentifier(source)
    if not identifier then return {} end

    local rows = MySQL.query.await(
        'SELECT * FROM lex_crafting_player_queue WHERE identifier = ? AND status IN (?, ?, ?, ?)',
        { identifier, 'crafting', 'queued', 'done', 'failed' }
    ) or {}

    local queue = {}
    for _, row in ipairs(rows) do
        table.insert(queue, {
            id = tostring(row.id),
            recipeId = row.recipe_id,
            name = row.label,
            yield = row.yield_amount,
            totalTime = row.total_time,
            timeLeft = row.time_left,
            successRate = row.success_rate,
            status = row.status,
        })
    end
    return queue
end

function LEXCrafting.SyncQueueToClient(source)
    TriggerClientEvent('lex_crafting:syncQueue', source, LEXCrafting.BuildQueuePayload(source))
end

function LEXCrafting.SyncInventoryToClient(source, pointId)
    local payload = LEXCrafting.BuildOpenPayload(source, pointId)
    if not payload then return end
    local owned = {}
    for _, cat in ipairs(LEXCrafting.AsArray(payload.categories)) do
        for _, recipe in ipairs(LEXCrafting.AsArray(cat.recipes)) do
            for _, ing in ipairs(LEXCrafting.AsArray(recipe.ingredients)) do
                if ing.item and ing.item ~= '' then
                    local count = ing.owned
                    if type(count) ~= 'number' then
                        count = LEXCrafting.GetItemCount(source, ing.item)
                    end
                    owned[ing.item] = count
                end
            end
        end
    end
    TriggerClientEvent('lex_crafting:syncInventory', source, owned)
end
