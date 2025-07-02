local isRecording = false
local recordingStartTime = 0

-- Initialize voice system
Citizen.CreateThread(function()
    if not Config.Voice.enabled then return end
    
    Utils.Debug("Voice system initialized")
    
    -- Check for pma-voice dependency
    if GetResourceState('pma-voice') ~= 'started' then
        Utils.Debug("Warning: pma-voice is not running. Voice features may not work properly.")
    end
end)

-- Start voice recording
RegisterNetEvent('npc-ai:startVoiceRecording')
AddEventHandler('npc-ai:startVoiceRecording', function()
    if not Config.Voice.speechToText.enabled then return end
    
    if isRecording then
        Utils.Debug("Already recording voice")
        return
    end
    
    Utils.Debug("Starting voice recording")
    isRecording = true
    recordingStartTime = GetGameTimer()
    
    -- Send to NUI to handle speech recognition
    SendNUIMessage({
        type = 'startSpeechRecognition',
        config = {
            language = Config.Voice.speechToText.language,
            continuous = true,
            interimResults = true
        }
    })
    
    -- Visual indicator that recording is active
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(255, 152, 0, 0.3); border-radius: 3px;"><b>🎤 Écoute...</b></div>',
        args = {}
    })
end)

-- Stop voice recording
RegisterNetEvent('npc-ai:stopVoiceRecording')
AddEventHandler('npc-ai:stopVoiceRecording', function()
    if not isRecording then return end
    
    Utils.Debug("Stopping voice recording")
    isRecording = false
    
    -- Send to NUI to stop speech recognition
    SendNUIMessage({
        type = 'stopSpeechRecognition'
    })
    
    -- Clear visual indicator
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(244, 67, 54, 0.3); border-radius: 3px;"><b>🔇 Arrêté</b></div>',
        args = {}
    })
end)

-- Handle speech recognition results from NUI
RegisterNUICallback('speechResult', function(data, cb)
    if not isRecording then 
        cb('error')
        return 
    end
    
    local transcript = data.transcript
    if not transcript or transcript == "" then
        cb('error')
        return
    end
    
    Utils.Debug("Speech recognized: " .. transcript)
    
    -- Display what was heard
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(33, 150, 243, 0.3); border-radius: 3px;"><b>Vous:</b> {0}</div>',
        args = { transcript }
    })
    
    -- Send to server for AI processing
    TriggerServerEvent('npc-ai:processPlayerSpeech', transcript)
    
    cb('ok')
end)

-- Handle speech recognition errors
RegisterNUICallback('speechError', function(data, cb)
    Utils.Debug("Speech recognition error: " .. tostring(data.error))
    
    -- Stop recording on error
    TriggerEvent('npc-ai:stopVoiceRecording')
    
    cb('ok')
end)

-- Play text-to-speech
RegisterNetEvent('npc-ai:playTTS')
AddEventHandler('npc-ai:playTTS', function(text, voice)
    if not Config.Voice.textToSpeech.enabled then return end
    
    Utils.Debug("Playing TTS: " .. text)
    
    -- Send to NUI for TTS processing
    SendNUIMessage({
        type = 'playTTS',
        text = text,
        voice = voice or Config.Voice.textToSpeech.voice,
        rate = 1.0,
        pitch = 1.0
    })
end)

-- Handle TTS completion
RegisterNUICallback('ttsComplete', function(data, cb)
    Utils.Debug("TTS playback completed")
    cb('ok')
end)

-- Handle TTS errors
RegisterNUICallback('ttsError', function(data, cb)
    Utils.Debug("TTS error: " .. tostring(data.error))
    cb('ok')
end)

-- Check for pma-voice proximity and integrate
Citizen.CreateThread(function()
    while Config.Voice.enabled do
        Citizen.Wait(500)
        
        -- Check if player is speaking using pma-voice
        local playerId = PlayerId()
        if exports['pma-voice']:getPlayerData(playerId, 'talking') then
            -- Player is talking through pma-voice
            if not isRecording then
                -- Auto-start voice recording when player talks
                TriggerEvent('npc-ai:startVoiceRecording')
            end
        else
            -- Player stopped talking
            if isRecording and GetGameTimer() - recordingStartTime > 1000 then
                -- Stop recording after a short delay
                Citizen.SetTimeout(2000, function()
                    if not exports['pma-voice']:getPlayerData(playerId, 'talking') then
                        TriggerEvent('npc-ai:stopVoiceRecording')
                    end
                end)
            end
        end
    end
end)

-- Manual voice activation (fallback)
RegisterCommand('npc_talk', function()
    if not isRecording then
        TriggerEvent('npc-ai:startVoiceRecording')
    else
        TriggerEvent('npc-ai:stopVoiceRecording')
    end
end, false)

-- Voice proximity detection using pma-voice
function GetVoiceProximityPlayers()
    local players = {}
    local playerId = PlayerId()
    
    if GetResourceState('pma-voice') == 'started' then
        -- Get players within voice range using pma-voice
        local voiceData = exports['pma-voice']:getPlayerData(playerId)
        if voiceData and voiceData.proximity then
            for _, player in pairs(voiceData.proximity) do
                table.insert(players, player)
            end
        end
    end
    
    return players
end

-- Integrate with pma-voice submixes for NPCs
function SetNPCVoiceSettings(npcEntity, volume, effects)
    if GetResourceState('pma-voice') ~= 'started' then return end
    
    -- Set custom voice settings for NPCs
    -- This would need to be coordinated with pma-voice
    Utils.Debug("Setting voice settings for NPC entity: " .. tostring(npcEntity))
end