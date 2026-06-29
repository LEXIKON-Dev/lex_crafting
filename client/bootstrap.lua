print('^2[lex_crafting]^7 CLIENT bootstrap start')



LEXCrafting = LEXCrafting or {}



local function openCreatorNui()

    if LEXCrafting.UiOpen then

        return

    end



    print('^2[lex_crafting]^7 openCreatorNui() aufgerufen')

    LEXCrafting.UiOpen = true

    if LEXCrafting.SetUiBlur then
        LEXCrafting.SetUiBlur(true)
    end

    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'openCreator' })

    TriggerServerEvent('lex_crafting:creatorOpened')

end



LEXCrafting.OpenCreatorNui = openCreatorNui



RegisterNetEvent('lex_crafting:forceOpenCreator', function()

    openCreatorNui()

    TriggerServerEvent('lex_crafting:requestCreatorConfig')

end)



RegisterNetEvent('lex_crafting:creatorAccess', function(allowed, _, message)

    if not allowed then

        print('^1[lex_crafting]^7 Creator verweigert: ' .. tostring(message))

        if LEXCrafting.NotifyClient then

            LEXCrafting.NotifyClient(message or 'Keine Berechtigung')

        end

    end

end)



RegisterNetEvent('lex_crafting:openCreator', function()

    openCreatorNui()

end)



RegisterNetEvent('lex_crafting:loadCreatorConfig', function(config)
    CreateThread(function()
        Wait(0)
        SendNUIMessage({ action = 'loadCreatorConfig', data = config })
    end)
end)



RegisterKeyMapping('lex_crafting_creator', 'LEX Crafting Creator oeffnen', 'keyboard', 'F7')

RegisterCommand('lex_crafting_creator', function()

    TriggerServerEvent('lex_crafting:requestCreator')

end, false)



CreateThread(function()

    Wait(1000)

    TriggerServerEvent('lex_crafting:clientPing')

    print('^2[lex_crafting]^7 CLIENT bootstrap fertig - /craftingcreator oder F7')

end)



AddEventHandler('onClientResourceStart', function(resourceName)

    if resourceName ~= GetCurrentResourceName() then return end

    print('^2[lex_crafting]^7 Client resource gestartet')

end)


