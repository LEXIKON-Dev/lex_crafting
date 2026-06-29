Config = {}

Config.Locale = 'de'

Config.AdminGroups = {
    'admin',
    'superadmin',
}

Config.CreatorCommand = 'craftingcreator'

-- Nur für Tests: true = jeder darf /craftingcreator nutzen
Config.AllowCreatorForAll = true

Config.InteractKey = 38 -- E

Config.DrawDistance = 25.0

Config.MarkerDrawDistance = 15.0

-- DB: Zeilen pro Batch-INSERT beim Creator-Speichern (groesser = weniger Queries)
Config.SaveBatchSize = 200

-- Latent-Event Bandbreite Bytes/s fuer grosse Config-Uebertragung
Config.ConfigSyncBps = 1000000

-- Spiel-Hintergrund verschwommen (FiveM Native, nicht CSS)
Config.EnableScreenBlur = true
Config.ScreenBlurFadeMs = 200