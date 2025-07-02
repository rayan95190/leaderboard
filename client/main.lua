local isNearNPC = false
local currentConversationNPC = nil
local activeNPCs = {}
local playerPed = nil

-- Initialize on resource start
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        playerPed = PlayerPedId()
        
        if Config.Voice.enabled then
            CheckNPCProximity()
        end
    end
end)

-- Check for nearby NPCs
function CheckNPCProximity()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyFound = false
    
    for npcId, npcData in pairs(activeNPCs) do
        if npcData.entity and DoesEntityExist(npcData.entity) then
            local npcCoords = GetEntityCoords(npcData.entity)
            local distance = Utils.GetDistance(playerCoords, npcCoords)
            
            if distance <= Config.Voice.proximityDistance then
                nearbyFound = true
                
                if not isNearNPC then
                    Utils.Debug("Player is near NPC: " .. npcData.name)
                    TriggerEvent('npc-ai:onNPCProximity', npcId, npcData)
                    isNearNPC = true
                end
                break
            end
        end
    end
    
    if not nearbyFound and isNearNPC then
        Utils.Debug("Player left NPC proximity")
        TriggerEvent('npc-ai:onNPCProximityExit')
        isNearNPC = false
        currentConversationNPC = nil
    end
end

-- Register a new NPC
function RegisterNPC(npcData)
    if not npcData or not npcData.id then
        Utils.Debug("Invalid NPC data provided")
        return false
    end
    
    activeNPCs[npcData.id] = npcData
    Utils.Debug("Registered NPC: " .. npcData.name)
    return true
end

-- Get nearby NPCs
function GetNearbyNPCs()
    local playerCoords = GetEntityCoords(playerPed)
    local nearby = {}
    
    for npcId, npcData in pairs(activeNPCs) do
        if npcData.entity and DoesEntityExist(npcData.entity) then
            local npcCoords = GetEntityCoords(npcData.entity)
            local distance = Utils.GetDistance(playerCoords, npcCoords)
            
            if distance <= Config.Voice.proximityDistance then
                table.insert(nearby, {
                    id = npcId,
                    data = npcData,
                    distance = distance
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    
    return nearby
end

-- Start conversation with NPC
function StartConversation(npcId)
    local npc = activeNPCs[npcId]
    if not npc then
        Utils.Debug("NPC not found: " .. tostring(npcId))
        return false
    end
    
    if currentConversationNPC then
        Utils.Debug("Already in conversation with another NPC")
        return false
    end
    
    currentConversationNPC = npcId
    Utils.Debug("Started conversation with: " .. npc.name)
    
    -- Notify server about conversation start
    TriggerServerEvent('npc-ai:startConversation', npcId)
    
    -- Start voice recording if enabled
    if Config.Voice.speechToText.enabled then
        TriggerEvent('npc-ai:startVoiceRecording')
    end
    
    return true
end

-- End conversation
function EndConversation()
    if not currentConversationNPC then return end
    
    Utils.Debug("Ending conversation with: " .. activeNPCs[currentConversationNPC].name)
    
    -- Notify server about conversation end
    TriggerServerEvent('npc-ai:endConversation', currentConversationNPC)
    
    -- Stop voice recording
    TriggerEvent('npc-ai:stopVoiceRecording')
    
    currentConversationNPC = nil
end

-- Handle NPC responses
RegisterNetEvent('npc-ai:receiveNPCResponse')
AddEventHandler('npc-ai:receiveNPCResponse', function(npcId, response)
    if currentConversationNPC ~= npcId then return end
    
    local npc = activeNPCs[npcId]
    if not npc then return end
    
    Utils.Debug("Received response from " .. npc.name .. ": " .. response)
    
    -- Display response in chat
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(76, 175, 80, 0.3); border-radius: 3px;"><b>{0}</b>: {1}</div>',
        args = { npc.name, response }
    })
    
    -- Play TTS if enabled
    if Config.Voice.textToSpeech.enabled then
        TriggerEvent('npc-ai:playTTS', response, npc.voice or Config.Voice.textToSpeech.voice)
    end
end)

-- Handle NPC spawn from server
RegisterNetEvent('npc-ai:spawnNPC')
AddEventHandler('npc-ai:spawnNPC', function(npcData)
    Utils.Debug("Spawning NPC: " .. npcData.name)
    
    -- Create NPC entity
    local model = GetHashKey(npcData.model or 'a_m_y_business_01')
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(1)
    end
    
    local npc = CreatePed(4, model, npcData.coords.x, npcData.coords.y, npcData.coords.z, npcData.heading or 0.0, false, true)
    
    -- Configure NPC
    SetEntityAsMissionEntity(npc, true, true)
    SetPedRandomComponentVariation(npc, false)
    SetPedRandomProps(npc)
    SetEntityCanBeDamaged(npc, false)
    SetPedCanRagdoll(npc, false)
    FreezeEntityPosition(npc, true)
    
    -- Add to active NPCs
    npcData.entity = npc
    RegisterNPC(npcData)
    
    SetModelAsNoLongerNeeded(model)
end)

-- Handle NPC despawn
RegisterNetEvent('npc-ai:despawnNPC')
AddEventHandler('npc-ai:despawnNPC', function(npcId)
    local npc = activeNPCs[npcId]
    if not npc then return end
    
    Utils.Debug("Despawning NPC: " .. npc.name)
    
    if npc.entity and DoesEntityExist(npc.entity) then
        DeleteEntity(npc.entity)
    end
    
    -- End conversation if active
    if currentConversationNPC == npcId then
        EndConversation()
    end
    
    activeNPCs[npcId] = nil
end)

-- Auto-conversation trigger on proximity
RegisterNetEvent('npc-ai:onNPCProximity')
AddEventHandler('npc-ai:onNPCProximity', function(npcId, npcData)
    if Config.Voice.autoActivation and not currentConversationNPC then
        Citizen.Wait(1000) -- Small delay to avoid instant triggering
        if isNearNPC then -- Check if still near
            StartConversation(npcId)
        end
    end
end)

-- Proximity exit handler
RegisterNetEvent('npc-ai:onNPCProximityExit')
AddEventHandler('npc-ai:onNPCProximityExit', function()
    if currentConversationNPC then
        Citizen.SetTimeout(5000, function() -- 5 second grace period
            if not isNearNPC then
                EndConversation()
            end
        end)
    end
end)

-- Exports
exports('RegisterNPC', RegisterNPC)
exports('GetNearbyNPCs', GetNearbyNPCs)
exports('StartConversation', StartConversation)