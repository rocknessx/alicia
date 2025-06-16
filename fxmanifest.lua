fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'QB-Alicia Script with Custom Logos'
version '1.0.0'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/lobi.html',
    'html/script.js',
    'html/style.css',
    'stream/diamond.png',
    'stream/club.png',
    'stream/heart.png',
    'stream/spade.png'
}

dependencies {
    'qb-core',
    'qb-target',
    'oxmysql'
}