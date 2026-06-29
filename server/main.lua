LEXCrafting = LEXCrafting or {}
LEXCrafting.Config = nil
LEXCrafting.Settings = nil

local ESX = exports['es_extended']:getSharedObject()

function LEXCrafting.GetESX()
    return ESX
end

function LEXCrafting.Notify(source, msg, ntype)
    if source == 0 or not msg or msg == '' then return end
    TriggerClientEvent('lex_crafting:clientNotify', source, msg, ntype or 'inform')
end

function LEXCrafting.OpenCreatorForPlayer(src)
    print('[lex_crafting] Sende forceOpenCreator an Spieler ' .. src)
    TriggerClientEvent('lex_crafting:forceOpenCreator', src)
end

function LEXCrafting.DenyCreatorForPlayer(src, message)
    TriggerClientEvent('lex_crafting:creatorAccess', src, false, nil, message or _U('no_permission'))
end

RegisterNetEvent('lex_crafting:requestOpen', function(pointId)
    local src = source
    LEXCrafting.HandleOpenRequest(src, pointId)
end)

RegisterNetEvent('lex_crafting:craft', function(data)
    local src = source
    LEXCrafting.HandleCraft(src, data)
end)

RegisterNetEvent('lex_crafting:claimAll', function(data)
    local src = source
    LEXCrafting.HandleClaimAll(src, data)
end)

RegisterNetEvent('lex_crafting:cancelCraft', function(data)
    local src = source
    LEXCrafting.HandleCancelCraft(src, data)
end)

RegisterNetEvent('lex_crafting:saveConfig', function(config)
    local src = source
    LEXCrafting.SaveConfig(src, config)
end)

RegisterNetEvent('lex_crafting:saveConfigStart', function(config)
    LEXCrafting.HandleSaveConfigStart(source, config)
end)

RegisterNetEvent('lex_crafting:saveConfigChunk', function(config)
    LEXCrafting.HandleSaveConfigChunk(source, config)
end)

RegisterNetEvent('lex_crafting:saveConfigFinish', function()
    LEXCrafting.HandleSaveConfigFinish(source)
end)

AddEventHandler('playerDropped', function()
    LEXCrafting.ClearCreatorSession(source)
end)

CreateThread(function()
    LEXCrafting.LoadAllConfigAwait()
    print('[lex_crafting] Config loaded')
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    LEXCrafting.EnsureConfigLoaded()
    LEXCrafting.SendConfigToPlayer(playerId, false)
end)

RegisterNetEvent('lex_crafting:requestConfig', function()
    local src = source
    LEXCrafting.EnsureConfigLoaded()
    LEXCrafting.SendConfigToPlayer(src, false)
end)

ESX.RegisterServerCallback('lex_crafting:canUseCreator', function(source, cb)
    cb(LEXCrafting.IsAdmin(source))
end)

RegisterNetEvent('lex_crafting:clientPing', function()
    print('[lex_crafting] Client aktiv bei Spieler ' .. source)
end)

RegisterNetEvent('lex_crafting:creatorOpened', function()
    print('[lex_crafting] Creator UI geoeffnet bei Spieler ' .. source)
end)

RegisterNetEvent('lex_crafting:requestCreator', function()
    local src = source
    if LEXCrafting.IsAdmin(src) or Config.AllowCreatorForAll then
        LEXCrafting.OpenCreatorForPlayer(src)
    else
        LEXCrafting.DenyCreatorForPlayer(src, _U('no_permission'))
    end
end)

RegisterNetEvent('lex_crafting:requestCreatorConfig', function()
    local src = source
    if LEXCrafting.IsAdmin(src) or Config.AllowCreatorForAll then
        LEXCrafting.EnsureConfigLoaded()
        local netConfig = LEXCrafting.CloneForNet(LEXCrafting.Config)
        LEXCrafting.SetCreatorSession(src, netConfig)
        TriggerLatentClientEvent('lex_crafting:loadCreatorConfig', src, LEXCrafting.ConfigSyncBps(), netConfig)
    end
end)

local creatorCmd = Config.CreatorCommand or 'craftingcreator'

RegisterCommand(creatorCmd, function(source)
    if source == 0 then
        print('[lex_crafting] Command only works in-game.')
        return
    end

    print('[lex_crafting] Server command /' .. creatorCmd .. ' von Spieler ' .. source)

    if LEXCrafting.IsAdmin(source) or Config.AllowCreatorForAll then
        LEXCrafting.OpenCreatorForPlayer(source)
    else
        LEXCrafting.DenyCreatorForPlayer(source, _U('no_permission'))
    end
end, false)

print('[lex_crafting] Server command registered: /' .. creatorCmd)
