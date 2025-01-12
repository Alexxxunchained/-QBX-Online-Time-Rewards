fx_version 'cerulean'
game 'gta5'

author 'MySowrd傅剑寒'
description 'A virtual currency is automatically given to the player after a certain amount of time online and can be used to purchase items in certain stores.'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

dependencies {
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
use_fxv2_oal 'yes'