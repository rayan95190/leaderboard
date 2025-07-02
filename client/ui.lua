-- UI management for NPC AI system
local uiVisible = false
local currentNPCData = nil
local conversationActive = false

-- Initialize UI system
Citizen.CreateThread(function()
    Utils.Debug("UI system initialized")
    
    -- Send initial UI config to NUI
    SendNUIMessage({
        type = 'init',
        config = {
            debug = Config.Debug,
            voice = Config.Voice,
            locale = Config.Locale
        }
    })
end)

-- Handle NUI callbacks
RegisterNUICallback('ready', function(data, cb)
    Utils.Debug("NUI is ready")
    cb('ok')
end)

-- Show conversation UI
function ShowConversationUI(npcData)
    currentNPCData = npcData
    conversationActive = true
    uiVisible = true
    
    SendNUIMessage({
        type = 'showConversation',
        npc = {
            id = npcData.id,
            name = npcData.name,
            personality = npcData.personality,
            job = npcData.job
        }
    })
    
    SetNuiFocus(false, false) -- Keep game focused
end

-- Hide conversation UI
function HideConversationUI()
    conversationActive = false
    uiVisible = false
    currentNPCData = nil
    
    SendNUIMessage({
        type = 'hideConversation'
    })
end

-- Add message to conversation
function AddConversationMessage(speaker, message, timestamp)
    if not conversationActive then return end
    
    SendNUIMessage({
        type = 'addMessage',
        message = {
            speaker = speaker,
            content = message,
            timestamp = timestamp or GetGameTimer(),
            npcId = currentNPCData and currentNPCData.id or nil
        }
    })
end

-- Show NPC information panel
function ShowNPCInfo(npcData)
    SendNUIMessage({
        type = 'showNPCInfo',
        npc = {
            id = npcData.id,
            name = npcData.name,
            personality = npcData.personality,
            job = npcData.job,
            backstory = npcData.backstory,
            mood = npcData.mood or 'neutral',
            traits = npcData.traits
        }
    })
end

-- Show voice status
function ShowVoiceStatus(status, text)
    SendNUIMessage({
        type = 'voiceStatus',
        status = status, -- 'listening', 'processing', 'speaking', 'idle'
        text = text or ''
    })
end

-- Show notification
function ShowNotification(message, type, duration)
    SendNUIMessage({
        type = 'notification',
        message = message,
        notificationType = type or 'info', -- 'info', 'success', 'warning', 'error'
        duration = duration or 5000
    })
end

-- Show job interview UI
function ShowJobInterviewUI(jobData, questions)
    SendNUIMessage({
        type = 'showJobInterview',
        job = jobData,
        questions = questions,
        currentQuestion = 1
    })
end

-- Show crime interaction UI
function ShowCrimeUI(crimeType, options)
    SendNUIMessage({
        type = 'showCrimeUI',
        crimeType = crimeType,
        options = options
    })
end

-- Update conversation status
function UpdateConversationStatus(status)
    SendNUIMessage({
        type = 'conversationStatus',
        status = status -- 'waiting', 'listening', 'processing', 'responding'
    })
end

-- Show debug information
function ShowDebugInfo(info)
    if not Config.Debug then return end
    
    SendNUIMessage({
        type = 'debug',
        info = info
    })
end

-- Event handlers
RegisterNetEvent('npc-ai:showUI')
AddEventHandler('npc-ai:showUI', function(uiType, data)
    if uiType == 'conversation' then
        ShowConversationUI(data)
    elseif uiType == 'npcInfo' then
        ShowNPCInfo(data)
    elseif uiType == 'jobInterview' then
        ShowJobInterviewUI(data.job, data.questions)
    elseif uiType == 'crime' then
        ShowCrimeUI(data.type, data.options)
    end
end)

RegisterNetEvent('npc-ai:hideUI')
AddEventHandler('npc-ai:hideUI', function(uiType)
    if uiType == 'conversation' or not uiType then
        HideConversationUI()
    end
    
    SendNUIMessage({
        type = 'hideUI',
        uiType = uiType
    })
end)

RegisterNetEvent('npc-ai:addMessage')
AddEventHandler('npc-ai:addMessage', function(speaker, message, timestamp)
    AddConversationMessage(speaker, message, timestamp)
end)

RegisterNetEvent('npc-ai:voiceStatus')
AddEventHandler('npc-ai:voiceStatus', function(status, text)
    ShowVoiceStatus(status, text)
end)

RegisterNetEvent('npc-ai:notification')
AddEventHandler('npc-ai:notification', function(message, type, duration)
    ShowNotification(message, type, duration)
end)

RegisterNetEvent('npc-ai:conversationTimeout')
AddEventHandler('npc-ai:conversationTimeout', function()
    ShowNotification("La conversation a expiré", "warning", 3000)
    HideConversationUI()
end)

RegisterNetEvent('npc-ai:jobInterviewResult')
AddEventHandler('npc-ai:jobInterviewResult', function(hired, jobData)
    local message = hired and 
        "Félicitations ! Vous avez été embauché comme " .. jobData.positions[1] or
        "Désolé, votre candidature n'a pas été retenue"
    local type = hired and "success" or "error"
    
    ShowNotification(message, type, 5000)
end)

RegisterNetEvent('npc-ai:policeAlert')
AddEventHandler('npc-ai:policeAlert', function(alertData)
    ShowNotification("Alerte police: " .. alertData.description, "warning", 10000)
end)

RegisterNetEvent('npc-ai:receiveDrugs')
AddEventHandler('npc-ai:receiveDrugs', function(drugName, quantity)
    ShowNotification("Vous avez reçu " .. quantity .. "x " .. drugName, "info", 3000)
end)

RegisterNetEvent('npc-ai:applyFine')
AddEventHandler('npc-ai:applyFine', function(amount)
    ShowNotification("Amende: -" .. amount .. "$", "error", 5000)
    -- Here you would integrate with economy system to remove money
end)

RegisterNetEvent('npc-ai:sendToJail')
AddEventHandler('npc-ai:sendToJail', function(duration)
    ShowNotification("Vous êtes en prison pour " .. duration .. " secondes", "error", 3000)
    -- Here you would implement jail mechanics
end)

-- Proximity UI updates
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if conversationActive and currentNPCData then
            local nearbyNPCs = GetNearbyNPCs()
            local currentNPCNearby = false
            
            for _, nearby in pairs(nearbyNPCs) do
                if nearby.id == currentNPCData.id then
                    currentNPCNearby = true
                    break
                end
            end
            
            if not currentNPCNearby then
                -- Player moved away from NPC
                HideConversationUI()
                ShowNotification("Vous êtes trop loin du NPC", "warning", 3000)
            end
        end
    end
end)

-- Handle conversation auto-start UI
RegisterNetEvent('npc-ai:onNPCProximity')
AddEventHandler('npc-ai:onNPCProximity', function(npcId, npcData)
    if Config.Voice.autoActivation then
        ShowNotification("Appuyez sur [E] pour parler à " .. npcData.name, "info", 2000)
    end
end)

-- Interaction prompts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isNearNPC and not conversationActive then
            local nearbyNPCs = GetNearbyNPCs()
            
            if #nearbyNPCs > 0 then
                local closestNPC = nearbyNPCs[1]
                
                -- Draw interaction prompt
                DrawText3D(
                    GetEntityCoords(closestNPC.data.entity),
                    "Appuyez sur [E] pour parler à " .. closestNPC.data.name
                )
                
                -- Handle interaction key
                if IsControlJustPressed(0, 38) then -- E key
                    StartConversation(closestNPC.id)
                end
            end
        end
    end
end)

-- Draw 3D text function
function DrawText3D(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    
    if onScreen then
        local factor = string.len(text) / 370
        local camCoords = GetGameplayCamCoords()
        local distance = #(coords - camCoords)
        local scale = (1 / distance) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        scale = scale * fov * 0.6
        
        SetTextScale(0.0, scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(screenX, screenY)
        
        -- Draw background rectangle
        local rectWidth = factor + 0.02
        local rectHeight = 0.03
        DrawRect(screenX, screenY, rectWidth, rectHeight, 0, 0, 0, 100)
    end
end

-- Debug UI commands
RegisterCommand('npc_ui_test', function()
    ShowNotification("Test notification", "info", 3000)
end, false)

RegisterCommand('npc_debug_toggle', function()
    Config.Debug = not Config.Debug
    ShowNotification("Debug mode: " .. (Config.Debug and "ON" or "OFF"), "info", 2000)
    
    SendNUIMessage({
        type = 'toggleDebug',
        enabled = Config.Debug
    })
end, false)

-- Cleanup UI on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SendNUIMessage({
            type = 'cleanup'
        })
    end
end)