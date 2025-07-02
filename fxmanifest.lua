fx_version 'cerulean'
game 'gta5'

name 'NPC AI Voice System'
description 'Advanced NPC AI system with voice interaction for FiveM'
author 'rayan95190'
version '1.0.0'

-- Dependencies
dependencies {
    'pma-voice'
}

-- Lua 5.4 syntax
lua54 'yes'

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/voice.lua',
    'client/npc.lua',
    'client/ui.lua'
}

-- Server scripts
server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/ai.lua',
    'server/jobs.lua',
    'server/crime.lua'
}

-- Shared scripts
shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

-- UI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/voice.js'
}

-- Exports
exports {
    'RegisterNPC',
    'GetNearbyNPCs',
    'StartConversation'
}

server_exports {
    'CreateNPC',
    'GetNPCData',
    'ProcessAIResponse'
}