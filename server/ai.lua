local http = require('socket.http')
local json = require('json')

-- Process AI requests
RegisterNetEvent('npc-ai:processAIRequest')
AddEventHandler('npc-ai:processAIRequest', function(npcId, playerId, message, isGreeting)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc then
        Utils.Debug("NPC not found for AI request: " .. tostring(npcId))
        return
    end
    
    Utils.Debug("Processing AI request for NPC " .. npc.name .. ": " .. message)
    
    -- Build context for AI
    local context = BuildAIContext(npc, playerId, message, isGreeting)
    
    -- Send request to Ollama
    SendOllamaRequest(npcId, playerId, context, function(response)
        if response then
            ProcessAIResponse(npcId, playerId, response)
        else
            -- Fallback response
            local fallback = GetFallbackResponse(npc, message)
            ProcessAIResponse(npcId, playerId, fallback)
        end
    end)
end)

-- Build context for AI request
function BuildAIContext(npc, playerId, message, isGreeting)
    local playerName = GetPlayerName(playerId)
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    
    -- Build system prompt
    local systemPrompt = Config.AI.systemPrompt .. "\n\n"
    systemPrompt = systemPrompt .. "Informations sur ton personnage:\n"
    systemPrompt = systemPrompt .. "- Nom: " .. npc.name .. "\n"
    systemPrompt = systemPrompt .. "- Personnalité: " .. npc.personality .. "\n"
    systemPrompt = systemPrompt .. "- Histoire: " .. npc.backstory .. "\n"
    
    if npc.job then
        systemPrompt = systemPrompt .. "- Travail: " .. npc.job .. "\n"
    end
    
    if npc.traits then
        systemPrompt = systemPrompt .. "- Traits de personnalité (1-10):\n"
        systemPrompt = systemPrompt .. "  * Ouverture: " .. npc.traits.openness .. "\n"
        systemPrompt = systemPrompt .. "  * Conscience: " .. npc.traits.conscientiousness .. "\n"
        systemPrompt = systemPrompt .. "  * Extraversion: " .. npc.traits.extraversion .. "\n"
        systemPrompt = systemPrompt .. "  * Agréabilité: " .. npc.traits.agreeableness .. "\n"
        systemPrompt = systemPrompt .. "  * Névrosisme: " .. npc.traits.neuroticism .. "\n"
    end
    
    -- Add memory context
    local memory = GetNPCMemoryForPlayer(npcId, playerIdentifier)
    if memory and #memory > 0 then
        systemPrompt = systemPrompt .. "\nMémoires précédentes avec " .. playerName .. ":\n"
        for _, mem in pairs(memory) do
            systemPrompt = systemPrompt .. "- " .. mem.content .. "\n"
        end
    end
    
    systemPrompt = systemPrompt .. "\nRéponds de manière naturelle et cohérente avec ta personnalité. Garde tes réponses relativement courtes (1-3 phrases). Tu peux proposer des activités ou services selon ton rôle."
    
    -- Build conversation history
    local conversation = GetPlayerConversation(playerId)
    local messages = {
        {
            role = "system",
            content = systemPrompt
        }
    }
    
    if conversation and conversation.context then
        for _, msg in pairs(conversation.context) do
            if msg.speaker == "player" then
                table.insert(messages, {
                    role = "user",
                    content = playerName .. " dit: " .. msg.message
                })
            elseif msg.speaker == "npc" then
                table.insert(messages, {
                    role = "assistant",
                    content = msg.message
                })
            end
        end
    end
    
    -- Add current message
    if not isGreeting then
        table.insert(messages, {
            role = "user",
            content = playerName .. " dit: " .. message
        })
    end
    
    return messages
end

-- Send request to Ollama
function SendOllamaRequest(npcId, playerId, messages, callback)
    if not Config.AI.enabled then
        callback(nil)
        return
    end
    
    local requestData = {
        model = Config.AI.model,
        messages = messages,
        options = {
            temperature = Config.AI.temperature,
            num_predict = 200, -- Limit response length
            top_p = 0.9
        },
        stream = false
    }
    
    local jsonData = json.encode(requestData)
    local url = Config.AI.endpoint .. "/api/chat"
    
    Utils.Debug("Sending request to Ollama: " .. url)
    
    -- Use async HTTP request
    PerformHttpRequest(url, function(errorCode, resultData, resultHeaders)
        if errorCode == 200 then
            local success, response = pcall(json.decode, resultData)
            if success and response and response.message and response.message.content then
                Utils.Debug("Received AI response: " .. response.message.content)
                callback(response.message.content)
            else
                Utils.Debug("Failed to parse Ollama response")
                callback(nil)
            end
        else
            Utils.Debug("Ollama request failed with code: " .. errorCode)
            callback(nil)
        end
    end, 'POST', jsonData, {
        ['Content-Type'] = 'application/json'
    })
end

-- Process AI response
function ProcessAIResponse(npcId, playerId, response)
    local conversation = GetPlayerConversation(playerId)
    if not conversation then return end
    
    -- Clean response
    local cleanResponse = Utils.CleanString(response)
    if cleanResponse == "" then
        cleanResponse = GetFallbackResponse(exports['npc-ai-voice']:GetNPCData(npcId), "")
    end
    
    -- Add to conversation context
    table.insert(conversation.context, {
        speaker = "npc",
        message = cleanResponse,
        timestamp = os.time()
    })
    
    -- Send response to client
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, cleanResponse)
    
    -- Check for special keywords for actions
    CheckForSpecialActions(npcId, playerId, cleanResponse)
end

-- Get fallback response based on NPC personality
function GetFallbackResponse(npc, message)
    local fallbacks = {
        friendly = "Désolé, je n'ai pas bien compris. Pouvez-vous répéter ?",
        grumpy = "Mmh... je ne sais pas quoi répondre à ça.",
        mysterious = "Intéressant... mais je préfère garder mes pensées pour moi.",
        cheerful = "Oh, je ne suis pas sûr de quoi dire ! Mais c'est amusant de parler avec vous !",
        serious = "Je dois réfléchir à votre question.",
        criminal = "Hé... on peut pas parler de tout ici, vous savez.",
        businessman = "Laissez-moi réfléchir à une proposition qui pourrait vous intéresser.",
        artist = "Ah, l'inspiration ne vient pas toujours quand on le souhaite...",
        worker = "Je ne suis peut-être pas la bonne personne à qui demander ça.",
        student = "Je suis encore en train d'apprendre, désolé !"
    }
    
    return fallbacks[npc.personality] or "Je ne sais pas trop quoi dire..."
end

-- Check for special actions in AI response
function CheckForSpecialActions(npcId, playerId, response)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc then return end
    
    local lowerResponse = string.lower(response)
    
    -- Job-related keywords
    if string.find(lowerResponse, "travail") or string.find(lowerResponse, "emploi") or string.find(lowerResponse, "job") then
        if Config.Jobs.enabled then
            TriggerEvent('npc-ai:initiateJobDiscussion', npcId, playerId)
        end
    end
    
    -- Crime-related keywords
    if string.find(lowerResponse, "drogue") or string.find(lowerResponse, "deal") or string.find(lowerResponse, "business") then
        if Config.Crime.enabled and npc.personality == "criminal" then
            TriggerEvent('npc-ai:initiateCrimeDiscussion', npcId, playerId)
        end
    end
    
    -- Emotional responses
    if string.find(lowerResponse, "content") or string.find(lowerResponse, "heureux") then
        TriggerEvent('npc-ai:updateNPCMood', npcId, "happy")
    elseif string.find(lowerResponse, "triste") or string.find(lowerResponse, "énervé") then
        TriggerEvent('npc-ai:updateNPCMood', npcId, "sad")
    end
end

-- Get NPC memory for specific player
function GetNPCMemoryForPlayer(npcId, playerIdentifier)
    -- This would typically come from the global npcMemory table
    -- For now, return empty to keep it simple
    return {}
end

-- Get player conversation
function GetPlayerConversation(playerId)
    -- This would access the global playerConversations table
    -- For now, return nil to keep it simple
    return nil
end

-- Update NPC mood/emotion
RegisterNetEvent('npc-ai:updateNPCMood')
AddEventHandler('npc-ai:updateNPCMood', function(npcId, mood)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc then return end
    
    Utils.Debug("Updating mood for NPC " .. npc.name .. " to " .. mood)
    
    -- Here you could trigger visual changes to the NPC
    -- Like facial expressions, animations, etc.
    
    -- Update all clients with the mood change
    TriggerClientEvent('npc-ai:npcMoodChanged', -1, npcId, mood)
end)

-- Generate contextual AI prompt based on situation
function GenerateContextualPrompt(npc, situation, additionalContext)
    local basePrompt = Config.AI.systemPrompt
    
    if situation == "job_interview" then
        basePrompt = basePrompt .. "\n\nTu mènes actuellement un entretien d'embauche. Pose des questions pertinentes et évalue les réponses du candidat de manière professionnelle mais en restant dans ton rôle de personnage."
    elseif situation == "crime_negotiation" then
        basePrompt = basePrompt .. "\n\nTu es impliqué dans une discussion sur des activités illégales. Sois prudent, discret, et méfiant. Ne révèle pas trop d'informations trop rapidement."
    elseif situation == "casual_conversation" then
        basePrompt = basePrompt .. "\n\nC'est une conversation décontractée. Sois naturel et engageant selon ta personnalité."
    end
    
    if additionalContext then
        basePrompt = basePrompt .. "\n\nContexte supplémentaire: " .. additionalContext
    end
    
    return basePrompt
end

-- Test Ollama connection
RegisterCommand('test_ollama', function(source, args, rawCommand)
    if source ~= 0 then return end -- Console only
    
    Utils.Debug("Testing Ollama connection...")
    
    local testMessages = {
        {
            role = "system",
            content = "Tu es un NPC de test. Réponds simplement 'Connexion réussie' si tu reçois ce message."
        },
        {
            role = "user",
            content = "Test de connexion"
        }
    }
    
    SendOllamaRequest("test", 0, testMessages, function(response)
        if response then
            Utils.Debug("Ollama test successful: " .. response)
        else
            Utils.Debug("Ollama test failed")
        end
    end)
end, true)