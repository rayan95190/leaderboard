local activeNPCs = {}
local playerConversations = {}
local npcMemory = {}

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    Utils.Debug("NPC AI System starting...")
    
    -- Initialize database
    TriggerEvent('npc-ai:initDatabase')
    
    -- Load NPCs from database
    Citizen.SetTimeout(2000, function()
        LoadNPCsFromDatabase()
    end)
    
    Utils.Debug("NPC AI System started successfully")
end)

-- Load NPCs from database
function LoadNPCsFromDatabase()
    MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.table_npcs, {}, function(result)
        if result then
            for _, npcData in pairs(result) do
                local npc = {
                    id = npcData.id,
                    name = npcData.name,
                    model = npcData.model,
                    coords = json.decode(npcData.coords),
                    heading = npcData.heading,
                    personality = npcData.personality,
                    traits = json.decode(npcData.traits),
                    backstory = npcData.backstory,
                    job = npcData.job,
                    criminal_record = json.decode(npcData.criminal_record or '[]'),
                    memory = {}
                }
                
                activeNPCs[npc.id] = npc
                Utils.Debug("Loaded NPC: " .. npc.name)
            end
            
            Utils.Debug("Loaded " .. #result .. " NPCs from database")
            SpawnNPCsForPlayers()
        end
    end)
end

-- Spawn NPCs for connected players
function SpawnNPCsForPlayers()
    for _, playerId in pairs(GetPlayers()) do
        TriggerEvent('npc-ai:updateNPCsForPlayer', tonumber(playerId))
    end
end

-- Update NPCs for a specific player based on proximity
RegisterNetEvent('npc-ai:updateNPCsForPlayer')
AddEventHandler('npc-ai:updateNPCsForPlayer', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    if not playerPed then return end
    
    local playerCoords = GetEntityCoords(playerPed)
    
    for npcId, npcData in pairs(activeNPCs) do
        local distance = Utils.GetDistance(playerCoords, npcData.coords)
        
        -- Spawn NPC if within spawn distance
        if distance <= Config.NPCs.spawnDistance then
            TriggerClientEvent('npc-ai:spawnNPC', playerId, npcData)
        -- Despawn if too far
        elseif distance > Config.NPCs.despawnDistance then
            TriggerClientEvent('npc-ai:despawnNPC', playerId, npcId)
        end
    end
end)

-- Handle player connecting
AddEventHandler('playerConnecting', function()
    local playerId = source
    Citizen.SetTimeout(5000, function() -- Wait for player to fully load
        TriggerEvent('npc-ai:updateNPCsForPlayer', playerId)
    end)
end)

-- Start conversation
RegisterNetEvent('npc-ai:startConversation')
AddEventHandler('npc-ai:startConversation', function(npcId)
    local playerId = source
    local npc = activeNPCs[npcId]
    
    if not npc then
        Utils.Debug("NPC not found for conversation: " .. tostring(npcId))
        return
    end
    
    if playerConversations[playerId] then
        Utils.Debug("Player " .. playerId .. " already in conversation")
        return
    end
    
    -- Initialize conversation
    playerConversations[playerId] = {
        npcId = npcId,
        startTime = os.time(),
        context = {},
        lastActivity = os.time()
    }
    
    -- Load NPC memory for this player
    LoadNPCMemory(npcId, GetPlayerIdentifier(playerId, 0))
    
    Utils.Debug("Started conversation between player " .. playerId .. " and NPC " .. npc.name)
    
    -- Send initial greeting
    local greeting = GenerateGreeting(npc, playerId)
    TriggerEvent('npc-ai:processAIRequest', npcId, playerId, greeting, true)
end)

-- End conversation
RegisterNetEvent('npc-ai:endConversation')
AddEventHandler('npc-ai:endConversation', function(npcId)
    local playerId = source
    
    if not playerConversations[playerId] then return end
    
    -- Save conversation to database
    SaveConversation(playerId, npcId, playerConversations[playerId])
    
    -- Update NPC memory
    SaveNPCMemory(npcId, GetPlayerIdentifier(playerId, 0), playerConversations[playerId].context)
    
    playerConversations[playerId] = nil
    
    Utils.Debug("Ended conversation between player " .. playerId .. " and NPC " .. npcId)
end)

-- Process player speech
RegisterNetEvent('npc-ai:processPlayerSpeech')
AddEventHandler('npc-ai:processPlayerSpeech', function(speechText)
    local playerId = source
    local conversation = playerConversations[playerId]
    
    if not conversation then
        Utils.Debug("No active conversation for player " .. playerId)
        return
    end
    
    local npc = activeNPCs[conversation.npcId]
    if not npc then
        Utils.Debug("NPC not found: " .. conversation.npcId)
        return
    end
    
    -- Clean and validate speech
    local cleanSpeech = Utils.CleanString(speechText)
    if cleanSpeech == "" then
        Utils.Debug("Empty speech received")
        return
    end
    
    Utils.Debug("Processing speech from player " .. playerId .. ": " .. cleanSpeech)
    
    -- Update conversation context
    table.insert(conversation.context, {
        speaker = "player",
        message = cleanSpeech,
        timestamp = os.time()
    })
    
    conversation.lastActivity = os.time()
    
    -- Process through AI
    TriggerEvent('npc-ai:processAIRequest', conversation.npcId, playerId, cleanSpeech, false)
end)

-- Generate initial greeting
function GenerateGreeting(npc, playerId)
    local greetings = {
        friendly = "Bonjour ! Comment allez-vous aujourd'hui ?",
        grumpy = "Qu'est-ce que vous voulez ?",
        mysterious = "Tiens, tiens... une nouvelle personne...",
        cheerful = "Salut ! Quelle belle journée, n'est-ce pas ?",
        serious = "Bonjour. Puis-je vous aider ?",
        criminal = "Hé... vous cherchez quelque chose de spécial ?",
        businessman = "Bonjour, êtes-vous intéressé par une opportunité d'affaires ?",
        artist = "Salut ! Appréciez-vous l'art ?",
        worker = "Bonjour, belle journée pour travailler !",
        student = "Salut ! Vous êtes d'ici ?"
    }
    
    return greetings[npc.personality] or "Bonjour !"
end

-- Create new NPC
function CreateNPC(npcData)
    if not npcData.id then
        npcData.id = Utils.GenerateId()
    end
    
    -- Set defaults
    npcData.personality = npcData.personality or Utils.GetRandomFromTable(Config.NPCs.personalities)
    npcData.traits = npcData.traits or Utils.GeneratePersonalityTraits()
    npcData.backstory = npcData.backstory or Utils.GenerateBackstory(npcData.personality, npcData.traits)
    npcData.criminal_record = npcData.criminal_record or {}
    
    -- Save to database
    MySQL.Async.execute('INSERT INTO ' .. Config.Database.table_npcs .. ' (id, name, model, coords, heading, personality, traits, backstory, job, criminal_record) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        npcData.id,
        npcData.name,
        npcData.model,
        json.encode(npcData.coords),
        npcData.heading,
        npcData.personality,
        json.encode(npcData.traits),
        npcData.backstory,
        npcData.job,
        json.encode(npcData.criminal_record)
    }, function(affectedRows)
        if affectedRows > 0 then
            activeNPCs[npcData.id] = npcData
            Utils.Debug("Created new NPC: " .. npcData.name)
            
            -- Spawn for all players
            SpawnNPCsForPlayers()
        end
    end)
    
    return npcData.id
end

-- Save conversation to database
function SaveConversation(playerId, npcId, conversationData)
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    
    MySQL.Async.execute('INSERT INTO ' .. Config.Database.table_conversations .. ' (player_identifier, npc_id, context, start_time, end_time) VALUES (?, ?, ?, ?, ?)', {
        playerIdentifier,
        npcId,
        json.encode(conversationData.context),
        conversationData.startTime,
        os.time()
    })
end

-- Load NPC memory for a player
function LoadNPCMemory(npcId, playerIdentifier)
    MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.table_memory .. ' WHERE npc_id = ? AND player_identifier = ? AND created_at > ?', {
        npcId,
        playerIdentifier,
        os.time() - (Config.NPCs.memoryDuration / 1000)
    }, function(result)
        if result and #result > 0 then
            npcMemory[npcId] = npcMemory[npcId] or {}
            npcMemory[npcId][playerIdentifier] = {}
            
            for _, memory in pairs(result) do
                table.insert(npcMemory[npcId][playerIdentifier], {
                    content = memory.content,
                    timestamp = memory.created_at
                })
            end
            
            Utils.Debug("Loaded " .. #result .. " memories for NPC " .. npcId)
        end
    end)
end

-- Save NPC memory
function SaveNPCMemory(npcId, playerIdentifier, context)
    if not context or #context == 0 then return end
    
    -- Create summary of conversation for memory
    local summary = "Conversation avec " .. GetPlayerName(GetPlayerFromIdentifier(playerIdentifier))
    if #context > 0 then
        summary = summary .. ": " .. context[#context].message
    end
    
    MySQL.Async.execute('INSERT INTO ' .. Config.Database.table_memory .. ' (npc_id, player_identifier, content, created_at) VALUES (?, ?, ?, ?)', {
        npcId,
        playerIdentifier,
        summary,
        os.time()
    })
end

-- Conversation timeout check
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        local currentTime = os.time()
        for playerId, conversation in pairs(playerConversations) do
            if currentTime - conversation.lastActivity > (Config.NPCs.conversationTimeout / 1000) then
                Utils.Debug("Conversation timeout for player " .. playerId)
                TriggerEvent('npc-ai:endConversation', conversation.npcId)
                TriggerClientEvent('npc-ai:conversationTimeout', playerId)
            end
        end
    end
end)

-- Player position update for NPC spawning
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Update every 10 seconds
        
        for _, playerId in pairs(GetPlayers()) do
            TriggerEvent('npc-ai:updateNPCsForPlayer', tonumber(playerId))
        end
    end
end)

-- Exports
exports('CreateNPC', CreateNPC)
exports('GetNPCData', function(npcId) return activeNPCs[npcId] end)
exports('ProcessAIResponse', function(npcId, playerId, response) TriggerEvent('npc-ai:processAIRequest', npcId, playerId, response, false) end)