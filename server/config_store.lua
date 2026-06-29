LEXCrafting = LEXCrafting or {}
LEXCrafting.SaveInProgress = false
LEXCrafting.CreatorSessions = LEXCrafting.CreatorSessions or {}
LEXCrafting.CreatorSaveBuffers = LEXCrafting.CreatorSaveBuffers or {}

function LEXCrafting.SetCreatorSession(source, config)
    if not source or type(config) ~= 'table' then return end
    LEXCrafting.CreatorSessions[source] = LEXCrafting.CloneForNet(config)
end

function LEXCrafting.ClearCreatorSession(source)
    LEXCrafting.CreatorSessions[source] = nil
    LEXCrafting.CreatorSaveBuffers[source] = nil
end

function LEXCrafting.MergeCreatorSave(source, partial)
    partial = partial or {}
    local session = LEXCrafting.CreatorSessions[source] or LEXCrafting.Config or {}
    local dirty = partial.dirty or {}

    local merged = {
        settings = session.settings or {},
        points = LEXCrafting.AsArray(session.points),
        recipes = LEXCrafting.AsArray(session.recipes),
    }

    if dirty.settings or partial.settings then
        merged.settings = partial.settings or merged.settings
    end
    if dirty.points or partial.points then
        merged.points = LEXCrafting.AsArray(partial.points or merged.points)
    end
    if dirty.recipes or partial.recipes then
        merged.recipes = LEXCrafting.AsArray(partial.recipes or merged.recipes)
    end

    return merged
end

function LEXCrafting.HandleSaveConfigStart(source, raw)
    local data = LEXCrafting.ParseCreatorConfig(raw)
    if type(data) ~= 'table' then return end

    LEXCrafting.CreatorSaveBuffers[source] = {
        settings = data.settings,
        points = data.points,
        recipes = {},
        expectedChunks = tonumber(data.recipeChunks) or 0,
        receivedChunks = 0,
        dirty = data.dirty or { recipes = true, points = true, settings = true },
    }
end

function LEXCrafting.HandleSaveConfigChunk(source, raw)
    local data = LEXCrafting.ParseCreatorConfig(raw)
    local buffer = LEXCrafting.CreatorSaveBuffers[source]
    if type(data) ~= 'table' or not buffer then return end

    for _, recipe in ipairs(LEXCrafting.AsArray(data.recipes)) do
        buffer.recipes[#buffer.recipes + 1] = recipe
    end
    buffer.receivedChunks = (buffer.receivedChunks or 0) + 1
end

function LEXCrafting.HandleSaveConfigFinish(source)
    local buffer = LEXCrafting.CreatorSaveBuffers[source]

    if buffer and buffer.expectedChunks > 0 then
        local waited = 0
        while buffer.receivedChunks < buffer.expectedChunks and waited < 5000 do
            Wait(50)
            waited = waited + 50
        end
    end

    LEXCrafting.CreatorSaveBuffers[source] = nil

    if not buffer then
        LEXCrafting.Notify(source, _U('config_save_failed'))
        TriggerClientEvent('lex_crafting:saveConfigResult', source, false, _U('config_save_failed'))
        return
    end

    LEXCrafting.SaveConfig(source, {
        settings = buffer.settings,
        points = buffer.points,
        recipes = buffer.recipes,
        dirty = buffer.dirty,
        mergeWithSession = false,
    })
end

local BATCH_SIZE = Config.SaveBatchSize or 200

local function collectEnabledRecipeIds(recipes)
    local ids = {}
    for _, recipe in ipairs(LEXCrafting.AsArray(recipes)) do
        if recipe.id and recipe.id ~= '' and LEXCrafting.DbBool(recipe.enabled, true) then
            ids[#ids + 1] = recipe.id
        end
    end
    return ids
end

local function pointHasRecipeAssignments(point)
    for _, cat in ipairs(LEXCrafting.AsArray(point.categories)) do
        if #LEXCrafting.AsArray(cat.recipeIds) > 0 then
            return true
        end
    end
    return false
end

local function trimField(value, maxLen)
    if value == nil then return '' end
    value = tostring(value)
    if #value > maxLen then
        return value:sub(1, maxLen)
    end
    return value
end

local function normalizeRecipeId(recipe)
    if type(recipe) ~= 'table' then return nil end
    local id = trimField(recipe.id, 64)
    if id == '' then return nil end
    recipe.id = id
    return id
end

local function dedupeRecipes(recipes)
    local seen = {}
    local result = {}

    for _, recipe in ipairs(LEXCrafting.AsArray(recipes)) do
        local id = normalizeRecipeId(recipe)
        if id and not seen[id] then
            seen[id] = true
            result[#result + 1] = recipe
        end
    end

    return result
end

local function addQuery(queries, query, values)
    queries[#queries + 1] = { query = query, values = values or {} }
end

local function buildPointInsertRow(point, pointId)
    local c = point.coords or {}
    local blip = point.blip or {}
    local marker = point.marker or {}
    local color = marker.color or {}
    local model = point.model
    if type(model) == 'string' and model ~= '' then
        model = trimField(model, 64)
    else
        model = ''
    end

    return {
        trimField(pointId, 64),
        trimField(point.name or pointId, 128),
        LEXCrafting.ToDbFlag(point.enabled, true),
        point.interactionType or 'marker',
        trimField(point.openKey or 'E', 8),
        tonumber(c.x) or 0.0,
        tonumber(c.y) or 0.0,
        tonumber(c.z) or 0.0,
        tonumber(c.heading) or 0.0,
        model,
        tonumber(point.interactionRadius) or 1.5,
        tonumber(point.maxCraftRadius) or 5.0,
        LEXCrafting.ToDbFlag(blip.enabled, false),
        tonumber(blip.sprite) or 89,
        tonumber(blip.color) or 3,
        tonumber(blip.scale) or 0.9,
        trimField(blip.label or 'Crafting', 64),
        tonumber(blip.showDistance) or 50,
        LEXCrafting.ToDbFlag(marker.enabled, true),
        tonumber(marker.type) or 1,
        tonumber(color.r) or 43,
        tonumber(color.g) or 161,
        tonumber(color.b) or 240,
        tonumber(color.a) or 180,
        tonumber(marker.size) or 1.0,
    }
end

function LEXCrafting.ParseCreatorConfig(raw)
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            return decoded
        end
        return nil
    end
    return raw
end

local function buildSaveQueries(settings, recipes, points)
    local queries = {}
    local recipeIdSet = {}
    local allRecipeIds = collectEnabledRecipeIds(recipes)

    local recipeRows = {}
    local ingredientRows = {}
    local recipeJobRows = {}
    local pointRows = {}
    local pointJobRows = {}
    local categoryRows = {}
    local categoryRecipeRows = {}

    addQuery(
        queries,
        [[UPDATE lex_crafting_settings SET max_queue = ?, use_categories = ?, hide_minimap = ?, locale = ?, default_open_key = ? WHERE id = 1]],
        {
            settings.maxQueue or 5,
            LEXCrafting.ToDbFlag(settings.useCategories, true),
            LEXCrafting.ToDbFlag(settings.hideMinimap, true),
            trimField(settings.locale or 'de', 8),
            trimField(settings.defaultOpenKey or 'E', 8),
        }
    )

    addQuery(queries, 'DELETE FROM lex_crafting_category_recipes', {})
    addQuery(queries, 'DELETE FROM lex_crafting_point_categories', {})
    addQuery(queries, 'DELETE FROM lex_crafting_point_jobs', {})
    addQuery(queries, 'DELETE FROM lex_crafting_recipe_jobs', {})
    addQuery(queries, 'DELETE FROM lex_crafting_recipe_ingredients', {})
    addQuery(queries, 'DELETE FROM lex_crafting_points', {})
    addQuery(queries, 'DELETE FROM lex_crafting_recipes', {})

    for _, recipe in ipairs(recipes) do
        local id = normalizeRecipeId(recipe)
        if not id then goto continue_recipe end

        recipeIdSet[id] = true
        recipeRows[#recipeRows + 1] = {
            id,
            trimField(recipe.item or id, 64),
            trimField(recipe.label or recipe.item or id, 128),
            trimField(recipe.category or 'Allgemein', 64),
            recipe.craftTime or 5,
            recipe.successRate or 100,
            recipe.yield or 1,
            LEXCrafting.ToDbFlag(recipe.enabled, true),
        }

        for _, ing in ipairs(LEXCrafting.AsArray(recipe.ingredients)) do
            if ing.item and ing.item ~= '' then
                ingredientRows[#ingredientRows + 1] = {
                    id,
                    trimField(ing.item, 64),
                    trimField(ing.label or ing.item, 128),
                    ing.amount or 1,
                }
            end
        end

        for _, job in ipairs(LEXCrafting.AsArray(recipe.jobs)) do
            if job.job and job.job ~= '' then
                recipeJobRows[#recipeJobRows + 1] = {
                    id,
                    trimField(job.job, 64),
                    job.minGrade or 0,
                }
            end
        end

        ::continue_recipe::
    end

    for _, point in ipairs(points) do
        if not point.id or point.id == '' then goto continue_point end

        local pointId = trimField(point.id, 64)
        pointRows[#pointRows + 1] = buildPointInsertRow(point, pointId)

        for _, job in ipairs(LEXCrafting.AsArray(point.jobs)) do
            if job.job and job.job ~= '' then
                pointJobRows[#pointJobRows + 1] = {
                    pointId,
                    trimField(job.job, 64),
                    job.minGrade or 0,
                }
            end
        end

        local pointCategories = LEXCrafting.AsArray(point.categories)
        if not pointHasRecipeAssignments(point) and #pointCategories > 0 and #allRecipeIds > 0 then
            pointCategories[1].recipeIds = allRecipeIds
        end

        for _, cat in ipairs(pointCategories) do
            if not cat.id or cat.id == '' then goto continue_category end

            local catId = trimField(cat.id, 64)
            categoryRows[#categoryRows + 1] = {
                catId,
                pointId,
                trimField(cat.label or 'Kategorie', 128),
                cat.sortOrder or 0,
            }

            for _, recipeId in ipairs(LEXCrafting.AsArray(cat.recipeIds)) do
                recipeId = trimField(recipeId, 64)
                if recipeId ~= '' and recipeIdSet[recipeId] then
                    categoryRecipeRows[#categoryRecipeRows + 1] = { catId, recipeId }
                end
            end

            ::continue_category::
        end

        ::continue_point::
    end

    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_recipes',
        { 'id', 'item', 'label', 'category', 'craft_time', 'success_rate', 'yield_amount', 'enabled' },
        recipeRows,
        BATCH_SIZE
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_recipe_ingredients',
        { 'recipe_id', 'item', 'label', 'amount' },
        ingredientRows,
        BATCH_SIZE
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_recipe_jobs',
        { 'recipe_id', 'job', 'min_grade' },
        recipeJobRows,
        BATCH_SIZE
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_points',
        {
            'id', 'name', 'enabled', 'interaction_type', 'open_key', 'coord_x', 'coord_y', 'coord_z', 'heading', 'model',
            'interaction_radius', 'max_craft_radius', 'blip_enabled', 'blip_sprite', 'blip_color', 'blip_scale', 'blip_label', 'blip_show_distance',
            'marker_enabled', 'marker_type', 'marker_color_r', 'marker_color_g', 'marker_color_b', 'marker_color_a', 'marker_size',
        },
        pointRows,
        math.max(#pointRows, 1)
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_point_jobs',
        { 'point_id', 'job', 'min_grade' },
        pointJobRows,
        BATCH_SIZE
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_point_categories',
        { 'id', 'point_id', 'label', 'sort_order' },
        categoryRows,
        BATCH_SIZE
    )
    LEXCrafting.AddBatchInserts(
        queries,
        'lex_crafting_category_recipes',
        { 'category_id', 'recipe_id' },
        categoryRecipeRows,
        BATCH_SIZE
    )

    return queries, #recipeRows, #pointRows
end

function LEXCrafting.SaveConfig(source, config)
    config = LEXCrafting.ParseCreatorConfig(config)

    if LEXCrafting.SaveInProgress then
        LEXCrafting.Notify(source, _U('config_save_busy'))
        TriggerClientEvent('lex_crafting:saveConfigResult', source, false, _U('config_save_busy'))
        return
    end

    if not LEXCrafting.IsAdmin(source) then
        LEXCrafting.Notify(source, _U('no_permission'))
        TriggerClientEvent('lex_crafting:saveConfigResult', source, false, _U('no_permission'))
        return
    end

    if type(config) ~= 'table' then
        LEXCrafting.Notify(source, _U('config_save_failed'))
        TriggerClientEvent('lex_crafting:saveConfigResult', source, false, _U('config_save_failed'))
        return
    end

    if config.mergeWithSession ~= false then
        config = LEXCrafting.MergeCreatorSave(source, config)
    end

    local recipes = dedupeRecipes(config.recipes)
    local points = LEXCrafting.AsArray(config.points)
    local settings = config.settings

    if not settings then
        settings = LEXCrafting.NormalizeSettings(LEXCrafting.Settings)
    end

    LEXCrafting.SaveInProgress = true

    CreateThread(function()
        local ok, recipeCount, pointCount = pcall(function()
            local queries, savedRecipes, savedPoints = buildSaveQueries(settings, recipes, points)
            MySQL.transaction.await(queries)
            return savedRecipes, savedPoints
        end)

        LEXCrafting.SaveInProgress = false

        if not ok then
            print(('[lex_crafting] SaveConfig failed: %s'):format(tostring(recipeCount)))
            LEXCrafting.Notify(source, _U('config_save_failed'))
            TriggerClientEvent('lex_crafting:saveConfigResult', source, false, _U('config_save_failed'))
            return
        end

        LEXCrafting.ApplyConfigFromSavePayload({
            recipes = recipes,
            points = points,
            settings = settings,
        })
        LEXCrafting.SetCreatorSession(source, LEXCrafting.Config)

        local detail = _U('config_saved_detail', recipeCount or #recipes, pointCount or #points)

        -- Sofort antworten – keine volle Config zurueck an den Speichernden (verhindert Client-Timeout)
        TriggerClientEvent('lex_crafting:saveConfigResult', source, true, detail)
        LEXCrafting.Notify(source, detail)

        CreateThread(function()
            local netConfig = LEXCrafting.CloneForNet(LEXCrafting.Config)
            LEXCrafting.BroadcastConfigAsync(source, netConfig)
        end)
    end)
end
