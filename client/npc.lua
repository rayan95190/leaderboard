-- NPC behavior and management
local npcBehaviors = {}
local npcAnimations = {}
local npcRoutes = {}

-- Initialize NPC behavior system
Citizen.CreateThread(function()
    Utils.Debug("NPC behavior system initialized")
    
    -- Start behavior update loop
    while true do
        Citizen.Wait(5000) -- Update every 5 seconds
        UpdateNPCBehaviors()
    end
end)

-- Update NPC behaviors
function UpdateNPCBehaviors()
    for npcId, npcData in pairs(activeNPCs) do
        if npcData.entity and DoesEntityExist(npcData.entity) then
            UpdateNPCBehavior(npcId, npcData)
        end
    end
end

-- Update individual NPC behavior
function UpdateNPCBehavior(npcId, npcData)
    local behavior = npcBehaviors[npcId]
    
    if not behavior then
        -- Initialize behavior for this NPC
        behavior = InitializeNPCBehavior(npcId, npcData)
        npcBehaviors[npcId] = behavior
    end
    
    -- Update behavior based on current state
    if behavior.state == "idle" then
        HandleIdleBehavior(npcId, npcData, behavior)
    elseif behavior.state == "walking" then
        HandleWalkingBehavior(npcId, npcData, behavior)
    elseif behavior.state == "conversation" then
        HandleConversationBehavior(npcId, npcData, behavior)
    elseif behavior.state == "working" then
        HandleWorkingBehavior(npcId, npcData, behavior)
    end
    
    -- Update mood animations
    UpdateNPCMoodAnimation(npcId, npcData, behavior)
end

-- Initialize NPC behavior
function InitializeNPCBehavior(npcId, npcData)
    local behavior = {
        state = "idle",
        mood = "neutral",
        energy = 100,
        lastStateChange = GetGameTimer(),
        nextActivityTime = GetGameTimer() + math.random(10000, 30000),
        personality = npcData.personality or "friendly",
        traits = npcData.traits or {},
        routine = GenerateNPCRoutine(npcData),
        socialInteractions = {},
        lastConversation = 0
    }
    
    Utils.Debug("Initialized behavior for NPC " .. npcData.name .. " with personality " .. behavior.personality)
    return behavior
end

-- Generate NPC routine based on personality and job
function GenerateNPCRoutine(npcData)
    local routine = {}
    local personality = npcData.personality or "friendly"
    
    -- Base routine for all NPCs
    table.insert(routine, {time = 8, activity = "work_start", duration = 480}) -- 8 hours work
    table.insert(routine, {time = 16, activity = "leisure", duration = 180}) -- 3 hours leisure
    table.insert(routine, {time = 19, activity = "social", duration = 120}) -- 2 hours social
    table.insert(routine, {time = 21, activity = "rest", duration = 660}) -- 11 hours rest
    
    -- Personality-specific modifications
    if personality == "criminal" then
        routine[2].activity = "illegal_activity"
        routine[3].activity = "network_meeting"
    elseif personality == "businessman" then
        routine[1].duration = 600 -- Longer work hours
        routine[3].activity = "networking"
    elseif personality == "artist" then
        routine[2].activity = "creative_work"
        routine[3].activity = "performance"
    end
    
    return routine
end

-- Handle idle behavior
function HandleIdleBehavior(npcId, npcData, behavior)
    local currentTime = GetGameTimer()
    
    if currentTime >= behavior.nextActivityTime then
        -- Decide next activity based on personality
        local activities = GetAvailableActivities(behavior.personality)
        local nextActivity = activities[math.random(1, #activities)]
        
        behavior.state = nextActivity
        behavior.lastStateChange = currentTime
        behavior.nextActivityTime = currentTime + math.random(15000, 45000)
        
        -- Start appropriate animation
        StartNPCActivity(npcId, npcData, nextActivity)
        
        Utils.Debug("NPC " .. npcData.name .. " starting activity: " .. nextActivity)
    else
        -- Random idle animations
        if math.random(1, 100) <= 5 then -- 5% chance
            PlayRandomIdleAnimation(npcData.entity)
        end
    end
end

-- Handle walking behavior
function HandleWalkingBehavior(npcId, npcData, behavior)
    local npcEntity = npcData.entity
    
    if not IsPedWalking(npcEntity) then
        -- NPC finished walking, return to idle
        behavior.state = "idle"
        behavior.lastStateChange = GetGameTimer()
        
        -- Generate new route occasionally
        if math.random(1, 100) <= 30 then -- 30% chance
            GenerateNPCRoute(npcId, npcData)
        end
    else
        -- Check if NPC should interact with nearby players or NPCs
        CheckForNearbyInteractions(npcId, npcData)
    end
end

-- Handle conversation behavior
function HandleConversationBehavior(npcId, npcData, behavior)
    -- This state is managed by the main conversation system
    -- Just update animations and mood
    if currentConversationNPC == npcId then
        -- NPC is actively talking to player
        if math.random(1, 100) <= 10 then -- 10% chance
            PlayConversationAnimation(npcData.entity)
        end
    else
        -- Conversation ended, return to idle
        behavior.state = "idle"
        behavior.lastConversation = GetGameTimer()
    end
end

-- Handle working behavior
function HandleWorkingBehavior(npcId, npcData, behavior)
    local currentTime = GetGameTimer()
    local workDuration = 300000 -- 5 minutes work session
    
    if currentTime - behavior.lastStateChange >= workDuration then
        behavior.state = "idle"
        behavior.energy = math.max(20, behavior.energy - 10)
        
        -- Work-specific animations
        PlayWorkAnimation(npcData.entity, npcData.job)
    end
end

-- Get available activities for personality type
function GetAvailableActivities(personality)
    local baseActivities = {"idle", "walking"}
    
    local personalityActivities = {
        friendly = {"walking", "social_gesture"},
        grumpy = {"idle", "grumpy_gesture"},
        mysterious = {"walking", "observing"},
        cheerful = {"walking", "happy_gesture", "dancing"},
        serious = {"working", "observing"},
        criminal = {"walking", "suspicious_activity"},
        businessman = {"working", "phone_call"},
        artist = {"creative_work", "performance"},
        worker = {"working", "tool_usage"},
        student = {"reading", "studying"}
    }
    
    local activities = personalityActivities[personality] or baseActivities
    return activities
end

-- Start NPC activity
function StartNPCActivity(npcId, npcData, activity)
    local npcEntity = npcData.entity
    
    if activity == "walking" then
        StartNPCWalk(npcId, npcData)
    elseif activity == "working" then
        StartWorkAnimation(npcEntity, npcData.job)
    elseif activity == "social_gesture" then
        PlaySocialAnimation(npcEntity, "friendly")
    elseif activity == "creative_work" then
        PlayCreativeAnimation(npcEntity)
    elseif activity == "suspicious_activity" then
        PlaySuspiciousAnimation(npcEntity)
    end
end

-- Start NPC walking
function StartNPCWalk(npcId, npcData)
    local npcEntity = npcData.entity
    local currentCoords = GetEntityCoords(npcEntity)
    
    -- Generate random nearby destination
    local angle = math.random() * 2 * math.pi
    local distance = math.random(5, 20)
    local newX = currentCoords.x + math.cos(angle) * distance
    local newY = currentCoords.y + math.sin(angle) * distance
    local newZ = currentCoords.z
    
    -- Get ground Z coordinate
    local groundFound, groundZ = GetGroundZFor_3dCoord(newX, newY, newZ, false)
    if groundFound then
        newZ = groundZ
    end
    
    -- Start walking to destination
    TaskGoToCoordAnyMeans(npcEntity, newX, newY, newZ, 1.0, 0, 0, 786603, 0xbf800000)
    
    Utils.Debug("NPC " .. npcData.name .. " walking to " .. newX .. ", " .. newY .. ", " .. newZ)
end

-- Generate NPC route
function GenerateNPCRoute(npcId, npcData)
    local route = {
        startCoords = GetEntityCoords(npcData.entity),
        waypoints = {},
        currentWaypoint = 1,
        completed = false
    }
    
    -- Generate 3-5 waypoints
    local numWaypoints = math.random(3, 5)
    for i = 1, numWaypoints do
        local angle = (i / numWaypoints) * 2 * math.pi
        local distance = math.random(10, 50)
        local x = route.startCoords.x + math.cos(angle) * distance
        local y = route.startCoords.y + math.sin(angle) * distance
        local z = route.startCoords.z
        
        table.insert(route.waypoints, vector3(x, y, z))
    end
    
    npcRoutes[npcId] = route
end

-- Animation functions
function PlayRandomIdleAnimation(npcEntity)
    local idleAnims = {
        {dict = "amb@world_human_hang_out_street@female_arms_crossed@base", anim = "base"},
        {dict = "amb@world_human_stand_impatient@male@no_sign@base", anim = "base"},
        {dict = "amb@world_human_smoking@male@male_a@base", anim = "base"},
        {dict = "amb@world_human_tourist_map@male@base", anim = "base"}
    }
    
    local selectedAnim = idleAnims[math.random(1, #idleAnims)]
    PlayNPCAnimation(npcEntity, selectedAnim.dict, selectedAnim.anim)
end

function PlayConversationAnimation(npcEntity)
    local talkAnims = {
        {dict = "mp_player_int_upper_salute", anim = "mp_player_int_salute"},
        {dict = "gestures@m@standing@casual", anim = "gesture_hello"},
        {dict = "gestures@m@standing@casual", anim = "gesture_point"},
        {dict = "gestures@m@standing@casual", anim = "gesture_what_hard"}
    }
    
    local selectedAnim = talkAnims[math.random(1, #talkAnims)]
    PlayNPCAnimation(npcEntity, selectedAnim.dict, selectedAnim.anim)
end

function PlayWorkAnimation(npcEntity, job)
    local workAnims = {
        mechanic = {dict = "amb@world_human_hammering@male@base", anim = "base"},
        doctor = {dict = "amb@medic@standing@kneel@base", anim = "base"},
        clerk = {dict = "amb@world_human_clipboard@male@base", anim = "base"},
        default = {dict = "amb@world_human_stand_mobile@male@text@base", anim = "base"}
    }
    
    local anim = workAnims[string.lower(job or "")] or workAnims.default
    PlayNPCAnimation(npcEntity, anim.dict, anim.anim)
end

function PlaySocialAnimation(npcEntity, mood)
    local socialAnims = {
        friendly = {dict = "gestures@m@standing@casual", anim = "gesture_hello"},
        happy = {dict = "anim@mp_player_intcelebrationmale@thumbs_up", anim = "thumbs_up"},
        grumpy = {dict = "gestures@m@standing@casual", anim = "gesture_damn"},
        mysterious = {dict = "amb@world_human_smoking@male@male_a@base", anim = "base"}
    }
    
    local anim = socialAnims[mood] or socialAnims.friendly
    PlayNPCAnimation(npcEntity, anim.dict, anim.anim)
end

function PlayCreativeAnimation(npcEntity)
    local creativeAnims = {
        {dict = "amb@world_human_musician@guitar@male@base", anim = "base"},
        {dict = "amb@world_human_mobile_film_shocking@female@base", anim = "base"},
        {dict = "amb@code_human_wander_texting@male@base", anim = "base"}
    }
    
    local selectedAnim = creativeAnims[math.random(1, #creativeAnims)]
    PlayNPCAnimation(npcEntity, selectedAnim.dict, selectedAnim.anim)
end

function PlaySuspiciousAnimation(npcEntity)
    local suspiciousAnims = {
        {dict = "amb@world_human_smoking@male@male_a@base", anim = "base"},
        {dict = "amb@world_human_stand_mobile@male@text@base", anim = "base"},
        {dict = "amb@world_human_drug_dealer_hard@male@base", anim = "base"}
    }
    
    local selectedAnim = suspiciousAnims[math.random(1, #suspiciousAnims)]
    PlayNPCAnimation(npcEntity, selectedAnim.dict, selectedAnim.anim)
end

function PlayNPCAnimation(npcEntity, animDict, animName, duration)
    if not DoesEntityExist(npcEntity) then return end
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(1)
    end
    
    TaskPlayAnim(npcEntity, animDict, animName, 8.0, -8.0, duration or 5000, 0, 0, false, false, false)
    RemoveAnimDict(animDict)
end

-- Update NPC mood animation
function UpdateNPCMoodAnimation(npcId, npcData, behavior)
    if not npcAnimations[npcId] then
        npcAnimations[npcId] = {
            lastAnimation = 0,
            currentMood = behavior.mood
        }
    end
    
    local animData = npcAnimations[npcId]
    local currentTime = GetGameTimer()
    
    -- Update mood-based facial expressions and posture
    if animData.currentMood ~= behavior.mood then
        SetNPCMoodExpression(npcData.entity, behavior.mood)
        animData.currentMood = behavior.mood
    end
    
    -- Periodic mood animations
    if currentTime - animData.lastAnimation > 15000 then -- Every 15 seconds
        PlayMoodAnimation(npcData.entity, behavior.mood)
        animData.lastAnimation = currentTime
    end
end

function SetNPCMoodExpression(npcEntity, mood)
    -- Set facial expression based on mood
    local expressions = {
        happy = "mood_happy_1",
        sad = "mood_sad_1", 
        angry = "mood_angry_1",
        neutral = "mood_normal_1",
        surprised = "mood_shocked_1"
    }
    
    local expression = expressions[mood] or expressions.neutral
    SetFacialIdleAnimOverride(npcEntity, expression, 0)
end

function PlayMoodAnimation(npcEntity, mood)
    local moodAnims = {
        happy = {dict = "anim@mp_player_intcelebrationmale@thumbs_up", anim = "thumbs_up"},
        sad = {dict = "anim@mp_player_intcelebrationmale@face_palm", anim = "face_palm"},
        angry = {dict = "gestures@m@standing@casual", anim = "gesture_damn"},
        neutral = {dict = "amb@world_human_hang_out_street@female_arms_crossed@base", anim = "base"}
    }
    
    local anim = moodAnims[mood] or moodAnims.neutral
    PlayNPCAnimation(npcEntity, anim.dict, anim.anim, 3000)
end

-- Check for nearby interactions
function CheckForNearbyInteractions(npcId, npcData)
    local npcCoords = GetEntityCoords(npcData.entity)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(npcCoords - playerCoords)
    
    -- React to nearby player
    if distance <= 5.0 and not currentConversationNPC then
        ReactToNearbyPlayer(npcId, npcData, distance)
    end
    
    -- Check for other NPCs
    CheckForNPCToNPCInteractions(npcId, npcData)
end

-- React to nearby player
function ReactToNearbyPlayer(npcId, npcData, distance)
    local behavior = npcBehaviors[npcId]
    if not behavior then return end
    
    local personality = behavior.personality
    local reactionChance = GetPersonalityReactionChance(personality)
    
    if math.random(1, 100) <= reactionChance then
        -- Make NPC look at player
        local playerPed = PlayerPedId()
        TaskLookAtEntity(npcData.entity, playerPed, 3000, 0, 2)
        
        -- Personality-based reactions
        if personality == "friendly" then
            PlaySocialAnimation(npcData.entity, "friendly")
        elseif personality == "grumpy" then
            PlaySocialAnimation(npcData.entity, "grumpy")
        elseif personality == "mysterious" then
            PlaySocialAnimation(npcData.entity, "mysterious")
        end
        
        Utils.Debug("NPC " .. npcData.name .. " reacted to nearby player")
    end
end

function GetPersonalityReactionChance(personality)
    local reactionChances = {
        friendly = 30,
        cheerful = 40,
        grumpy = 10,
        mysterious = 5,
        serious = 15,
        criminal = 8,
        businessman = 20,
        artist = 25,
        worker = 15,
        student = 35
    }
    
    return reactionChances[personality] or 15
end

-- Check for NPC to NPC interactions
function CheckForNPCToNPCInteractions(npcId, npcData)
    -- This would implement NPC-to-NPC conversations
    -- For now, just a placeholder
    Utils.Debug("Checking NPC-to-NPC interactions for " .. npcData.name)
end

-- Handle NPC mood changes
RegisterNetEvent('npc-ai:npcMoodChanged')
AddEventHandler('npc-ai:npcMoodChanged', function(npcId, mood)
    local behavior = npcBehaviors[npcId]
    if behavior then
        behavior.mood = mood
        Utils.Debug("NPC " .. npcId .. " mood changed to " .. mood)
    end
end)

-- Clean up NPC behaviors when NPCs are despawned
RegisterNetEvent('npc-ai:cleanupNPCBehavior')
AddEventHandler('npc-ai:cleanupNPCBehavior', function(npcId)
    npcBehaviors[npcId] = nil
    npcAnimations[npcId] = nil
    npcRoutes[npcId] = nil
    Utils.Debug("Cleaned up behavior data for NPC " .. npcId)
end)