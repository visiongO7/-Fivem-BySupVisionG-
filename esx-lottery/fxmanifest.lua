fx_version 'cerulean'
game 'gta5'

author 'SupVisionG'
description 'ESX Lottery System (乐透彩票系统)'
version '1.0.0'

dependencies {
    'es_extended',
    'oxmysql'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}