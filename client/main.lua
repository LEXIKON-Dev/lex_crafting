LEXCrafting = LEXCrafting or {}

local ESX = nil

function LEXCrafting.SetUiBlur(enabled)
    if Config.EnableScreenBlur == false then return end
    local ms = tonumber(Config.ScreenBlurFadeMs) or 200
    if enabled then
        TriggerScreenblurFadeIn(ms)
    else
        TriggerScreenblurFadeOut(ms)
    end
end

CreateThread(function()
    while not ESX do
        local ok, result = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and result then
            ESX = result
        end
        Wait(500)
    end
end)

local lastNotifyMsg, lastNotifyAt = nil, 0

function LEXCrafting.NotifyClient(msg, ntype)
    if not msg or msg == '' then return end

    local now = GetGameTimer()
    if msg == lastNotifyMsg and (now - lastNotifyAt) < 500 then
        return
    end
    lastNotifyMsg = msg
    lastNotifyAt = now

    ntype = ntype or 'inform'

    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({ description = msg, type = ntype })
        return
    end

    -- Ein Weg fuer ESX: Event statt ShowNotification (vermeidet Doppel-Anzeige auf vielen Servern)
    if ESX then
        TriggerEvent('esx:showNotification', msg)
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

RegisterNetEvent('lex_crafting:receiveConfig', function(config, settings)
    CreateThread(function()
        LEXCrafting.ClientConfig = config
        LEXCrafting.ClientSettings = settings
        if LEXCrafting.PreparePointCache then
            LEXCrafting.PreparePointCache()
        end
        if LEXCrafting.ScheduleRefreshPoints then
            LEXCrafting.ScheduleRefreshPoints()
        elseif LEXCrafting.RefreshPoints then
            LEXCrafting.RefreshPoints()
        end
    end)
end)

function LEXCrafting.ApplyLocalClientConfig(partial)
    if type(partial) ~= 'table' then return end
    LEXCrafting.ClientConfig = LEXCrafting.ClientConfig or {}
    if partial.points then
        LEXCrafting.ClientConfig.points = partial.points
    end
    if partial.recipes then
        LEXCrafting.ClientConfig.recipes = partial.recipes
    end
    if partial.settings then
        LEXCrafting.ClientConfig.settings = partial.settings
        LEXCrafting.ClientSettings = partial.settings
    end
    if LEXCrafting.PreparePointCache then
        LEXCrafting.PreparePointCache()
    end
    if LEXCrafting.ScheduleRefreshPoints then
        LEXCrafting.ScheduleRefreshPoints()
    end
end

RegisterNetEvent('lex_crafting:clientNotify', function(msg, ntype)
    LEXCrafting.NotifyClient(msg, ntype)
end)

RegisterNetEvent('lex_crafting:openUi', function(payload, queue)
    LEXCrafting.CurrentPointId = payload.pointId
    LEXCrafting.OpenCrafting(payload, queue)
end)

RegisterNetEvent('lex_crafting:syncQueue', function(queue)
    SendNUIMessage({ action = 'updateQueue', data = { queue = queue } })
end)

RegisterNetEvent('lex_crafting:syncInventory', function(owned)
    SendNUIMessage({ action = 'updateInventory', data = { owned = owned } })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('lex_crafting:requestConfig')
end)

RegisterNetEvent('esx:playerLoaded', function()
    TriggerServerEvent('lex_crafting:requestConfig')
end)

function LEXCrafting.NormalizePayload(payload)
    if type(payload) ~= 'table' then return payload end
    local ok, decoded = pcall(json.decode, json.encode(payload))
    if ok and type(decoded) == 'table' then
        return decoded
    end
    return payload
end

function LEXCrafting.OpenCrafting(payload, queue)
    payload = LEXCrafting.NormalizePayload(payload)
    queue = LEXCrafting.NormalizePayload(queue)
    LEXCrafting.UiOpen = true
    LEXCrafting.SetUiBlur(true)
    if LEXCrafting.ClientSettings and LEXCrafting.ClientSettings.hideMinimap then
        DisplayRadar(false)
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'closeCreator' })
    SendNUIMessage({ action = 'open', data = payload })
    if queue then
        SendNUIMessage({ action = 'updateQueue', data = { queue = queue } })
    end
    CreateThread(function()
        Wait(50)
        SendNUIMessage({ action = 'open', data = payload })
    end)
end

function LEXCrafting.CloseAllNui()
    LEXCrafting.UiOpen = false
    LEXCrafting.CurrentPointId = nil
    LEXCrafting.SetUiBlur(false)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    SendNUIMessage({ action = 'close' })
    SendNUIMessage({ action = 'closeCreator' })
end

function LEXCrafting.CloseUi()
    LEXCrafting.CloseAllNui()
end

function LEXCrafting.CloseCreator()
    LEXCrafting.CloseAllNui()
end

function LEXCrafting.OpenCreator()
    if LEXCrafting.OpenCreatorNui then
        LEXCrafting.OpenCreatorNui()
        return
    end
    LEXCrafting.UiOpen = true
    LEXCrafting.SetUiBlur(true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCreator' })
end

function LEXCrafting.OpenCreatorAccess(config)
    if config then
        SendNUIMessage({ action = 'loadCreatorConfig', data = config })
    end
    LEXCrafting.OpenCreator()
    LEXCrafting.NotifyClient('Crafting Creator geoeffnet')
end

print('^2[lex_crafting]^7 main.lua geladen')

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerScreenblurFadeOut(0)
end)
