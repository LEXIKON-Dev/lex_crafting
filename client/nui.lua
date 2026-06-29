LEXCrafting = LEXCrafting or {}

local function armSaveTimeout(cb)
    SetTimeout(60000, function()
        if LEXCrafting.PendingSaveCallback == cb then
            LEXCrafting.PendingSaveCallback({ success = false, message = 'Speichern hat zu lange gedauert.' })
            LEXCrafting.PendingSaveCallback = nil
            LEXCrafting.PendingSaveConfig = nil
        end
    end)
end

local function sendSaveEvent(eventName, data)
    CreateThread(function()
        Wait(0)
        TriggerServerEvent(eventName, data)
    end)
end

RegisterNUICallback('close', function(_, cb)
    if LEXCrafting.CloseAllNui then
        LEXCrafting.CloseAllNui()
    end
    cb('ok')
end)

RegisterNUICallback('craft', function(data, cb)
    TriggerServerEvent('lex_crafting:craft', data)
    cb('ok')
end)

RegisterNUICallback('claimAll', function(data, cb)
    TriggerServerEvent('lex_crafting:claimAll', data)
    cb('ok')
end)

RegisterNUICallback('cancelCraft', function(data, cb)
    TriggerServerEvent('lex_crafting:cancelCraft', data)
    cb('ok')
end)

RegisterNUICallback('getCurrentCoords', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped),
    })
end)

RegisterNUICallback('teleportToCoords', function(data, cb)
    local ped = PlayerPedId()
    local x = tonumber(data.x) or 0.0
    local y = tonumber(data.y) or 0.0
    local z = tonumber(data.z) or 0.0
    local heading = tonumber(data.heading) or 0.0

    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, heading)
    cb('ok')
end)

-- Kleines Partial-Save (z. B. nur Points/Blip) – Rezepte bleiben auf dem Server in der Session
RegisterNUICallback('saveConfig', function(data, cb)
    LEXCrafting.PendingSaveCallback = cb
    LEXCrafting.PendingSaveConfig = data
    sendSaveEvent('lex_crafting:saveConfig', data)
    armSaveTimeout(cb)
end)

RegisterNUICallback('saveConfigStart', function(data, cb)
    LEXCrafting.PendingSaveConfig = {
        settings = data.settings,
        points = data.points,
    }
    cb({ ok = true })
    sendSaveEvent('lex_crafting:saveConfigStart', data)
end)

RegisterNUICallback('saveConfigChunk', function(data, cb)
    cb({ ok = true })
    sendSaveEvent('lex_crafting:saveConfigChunk', data)
end)

RegisterNUICallback('saveConfigFinish', function(_, cb)
    LEXCrafting.PendingSaveCallback = cb
    TriggerServerEvent('lex_crafting:saveConfigFinish')
    armSaveTimeout(cb)
end)

RegisterNetEvent('lex_crafting:saveConfigResult', function(success, message)
    CreateThread(function()
        if success and LEXCrafting.PendingSaveConfig then
            LEXCrafting.ApplyLocalClientConfig(LEXCrafting.PendingSaveConfig)
            LEXCrafting.PendingSaveConfig = nil
        elseif not success then
            LEXCrafting.PendingSaveConfig = nil
        end

        if LEXCrafting.PendingSaveCallback then
            LEXCrafting.PendingSaveCallback({ success = success == true, message = message or '' })
            LEXCrafting.PendingSaveCallback = nil
        end
    end)
end)

RegisterNUICallback('ready', function(_, cb)
    print('^2[lex_crafting]^7 NUI React ready')
    cb('ok')
end)

RegisterNetEvent('lex_crafting:requestConfig', function()
    TriggerServerEvent('lex_crafting:requestConfig')
end)

CreateThread(function()
    while true do
        if LEXCrafting.UiOpen then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) then
                if LEXCrafting.CloseAllNui then
                    LEXCrafting.CloseAllNui()
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)
