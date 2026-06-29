fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lex_crafting'
description 'LEX Crafting System with Creator'
version '1.0.0'

ui_page 'ui/index.html'

shared_scripts {
    'shared/lex_init.lua',
    'shared/config.lua',
    'locales/de.lua',
}

client_scripts {
    'client/bootstrap.lua',
    'client/main.lua',
    'client/points.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/config_store.lua',
    'server/crafting.lua',
}

files {
    'ui/**/*',
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory',
}
