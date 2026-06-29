LEXCrafting = LEXCrafting or {}
LEXCrafting.Blips = LEXCrafting.Blips or {}
LEXCrafting.SpawnedEntities = LEXCrafting.SpawnedEntities or {}

local ESX = nil

CreateThread(function()
    while not ESX do
        local ok, result = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and result then ESX = result end
        Wait(500)
    end
end)

local function asArray(value)
    if type(value) ~= 'table' then return {} end
    return value
end

local refreshScheduled = false

function LEXCrafting.PreparePointCache()
    local points = LEXCrafting.ClientConfig and asArray(LEXCrafting.ClientConfig.points) or {}
    for _, point in ipairs(points) do
        if point and point.coords then
            local c = point.coords
            point._pos = vector3(c.x, c.y, c.z)
        end
    end
end

function LEXCrafting.ScheduleRefreshPoints()
    if refreshScheduled then return end
    refreshScheduled = true
    CreateThread(function()
        Wait(50)
        refreshScheduled = false
        LEXCrafting.RefreshPoints()
    end)
end

local function loadModel(model)
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then
            return false
        end
        Wait(10)
    end
    return true
end

function LEXCrafting.ClearBlips()
    if type(LEXCrafting.Blips) ~= 'table' then
        LEXCrafting.Blips = {}
        return
    end

    for _, blip in pairs(LEXCrafting.Blips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    LEXCrafting.Blips = {}
end

function LEXCrafting.ClearEntities()
    if type(LEXCrafting.SpawnedEntities) ~= 'table' then
        LEXCrafting.SpawnedEntities = {}
        return
    end

    for _, entity in pairs(LEXCrafting.SpawnedEntities) do
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    LEXCrafting.SpawnedEntities = {}
end

function LEXCrafting.SpawnPointEntity(point)
    LEXCrafting.SpawnedEntities = asArray(LEXCrafting.SpawnedEntities)
    if point.interactionType == 'ped' and point.model then
        local model = joaat(point.model)
        if not loadModel(model) then return end
        local c = point.coords
        local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.heading, false, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        table.insert(LEXCrafting.SpawnedEntities, ped)
    elseif point.interactionType == 'object' and point.model then
        local model = joaat(point.model)
        if not loadModel(model) then return end
        local c = point.coords
        local obj = CreateObject(model, c.x, c.y, c.z - 1.0, false, false, false)
        SetEntityHeading(obj, c.heading)
        FreezeEntityPosition(obj, true)
        SetModelAsNoLongerNeeded(model)
        table.insert(LEXCrafting.SpawnedEntities, obj)
    end
end

function LEXCrafting.RefreshPoints()
    LEXCrafting.Blips = asArray(LEXCrafting.Blips)
    LEXCrafting.SpawnedEntities = asArray(LEXCrafting.SpawnedEntities)
    LEXCrafting.ClearBlips()
    LEXCrafting.ClearEntities()

    local points = LEXCrafting.ClientConfig and asArray(LEXCrafting.ClientConfig.points) or {}
    if #points == 0 then return end

    for _, point in ipairs(points) do
        if point and point.enabled then
            if point.blip and point.blip.enabled and point.coords then
                local c = point.coords
                local blip = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipSprite(blip, point.blip.sprite or 89)
                SetBlipColour(blip, point.blip.color or 3)
                SetBlipScale(blip, point.blip.scale or 0.9)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(point.blip.label or point.name)
                EndTextCommandSetBlipName(blip)
                LEXCrafting.Blips[point.id] = blip
            end
            LEXCrafting.SpawnPointEntity(point)
        end
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local points = LEXCrafting.ClientConfig and asArray(LEXCrafting.ClientConfig.points) or {}

        if #points > 0 and not LEXCrafting.UiOpen then
            for _, point in ipairs(points) do
                if point and point.enabled and point.coords then
                    local p = point._pos or vector3(point.coords.x, point.coords.y, point.coords.z)
                    local dist = #(coords - p)

                    if dist < Config.DrawDistance then
                        sleep = 0

                        if point.marker and point.marker.enabled and dist < Config.MarkerDrawDistance then
                            local m = point.marker
                            local c = point.coords
                            DrawMarker(
                                m.type or 1,
                                c.x, c.y, c.z - 0.98,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                m.size or 1.0, m.size or 1.0, 0.5,
                                m.color.r, m.color.g, m.color.b, m.color.a,
                                false, false, 2, false, nil, nil, false
                            )
                        end

                        if dist <= (point.interactionRadius or 1.5) then
                            if ESX and ESX.ShowHelpNotification then
                                ESX.ShowHelpNotification(_U('open_workbench', point.name))
                            end
                            if IsControlJustReleased(0, Config.InteractKey) then
                                TriggerServerEvent('lex_crafting:requestOpen', point.id)
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    LEXCrafting.ClearBlips()
    LEXCrafting.ClearEntities()
end)

print('^2[lex_crafting]^7 points.lua geladen')
