fx_version 'cerulean'
game 'gta5'

name 'MySword_OnlineCoins'
author 'MySword傅剑寒'
description '通过挂机而自动获得赞助币的系统 Online time reward coins and buy some shit'

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