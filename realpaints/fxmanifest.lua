fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'realpaints'
description 'Real-world factory paints: usable spray can item and /realpaint command'

dependencies {
  'qb-core',
  'ox_lib',
  'oxmysql',
  'jg-mechanic',
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/realpaints-data.lua',
  'shared/paints.lua',
}

client_scripts {
  'client.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua',
}
