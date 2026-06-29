LEXCrafting = LEXCrafting or {}

if not IsDuplicityVersion() then
    LEXCrafting.Blips = LEXCrafting.Blips or {}
    LEXCrafting.SpawnedEntities = LEXCrafting.SpawnedEntities or {}
    LEXCrafting.ClientConfig = LEXCrafting.ClientConfig or nil
    LEXCrafting.ClientSettings = LEXCrafting.ClientSettings or nil
    LEXCrafting.UiOpen = LEXCrafting.UiOpen or false
    LEXCrafting.CurrentPointId = LEXCrafting.CurrentPointId or nil
else
    LEXCrafting.Config = LEXCrafting.Config or nil
    LEXCrafting.Settings = LEXCrafting.Settings or nil
end
