-- Crime system for NPCs
local activeDrugDeals = {}
local criminalNetworks = {}
local policeAlerts = {}

-- Initialize crime system
RegisterNetEvent('npc-ai:initiateCrimeDiscussion')
AddEventHandler('npc-ai:initiateCrimeDiscussion', function(npcId, playerId)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc or npc.personality ~= "criminal" then return end
    
    Utils.Debug("Initiating crime discussion between player " .. playerId .. " and criminal NPC " .. npc.name)
    
    -- Check player's criminal reputation
    local playerRep = GetPlayerCriminalReputation(GetPlayerIdentifier(playerId, 0))
    
    if playerRep < 10 then
        -- Player is unknown, be cautious
        StartCrimeIntroduction(npcId, playerId)
    else
        -- Player has reputation, offer business
        StartCrimeBusiness(npcId, playerId)
    end
end)

-- Start crime introduction for new players
function StartCrimeIntroduction(npcId, playerId)
    local responses = {
        "Hé... je ne vous connais pas. Qui vous a envoyé ?",
        "Vous cherchez quelque chose de spécial ? Il faut prouver qu'on peut vous faire confiance.",
        "Les affaires, ça ne se fait pas avec n'importe qui. Vous avez des références ?",
        "Doucement... on ne se connaît pas encore. Qu'est-ce que vous voulez exactement ?"
    }
    
    local response = responses[math.random(1, #responses)]
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
    
    -- Set up introduction state
    activeDrugDeals[playerId] = {
        npcId = npcId,
        stage = "introduction",
        startTime = os.time(),
        trustLevel = 0
    }
end

-- Start crime business for known players
function StartCrimeBusiness(npcId, playerId)
    local response = "Ah, vous ! J'ai ce qu'il vous faut. Qu'est-ce qui vous intéresse aujourd'hui ?"
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
    
    -- Set up business state
    activeDrugDeals[playerId] = {
        npcId = npcId,
        stage = "business",
        startTime = os.time(),
        trustLevel = 100
    }
end

-- Process crime interaction
RegisterNetEvent('npc-ai:processCrimeInteraction')
AddEventHandler('npc-ai:processCrimeInteraction', function(playerMessage)
    local playerId = source
    local deal = activeDrugDeals[playerId]
    
    if not deal then return end
    
    local messageLower = string.lower(playerMessage)
    
    if deal.stage == "introduction" then
        ProcessCrimeIntroduction(playerId, messageLower)
    elseif deal.stage == "business" then
        ProcessCrimeBusiness(playerId, messageLower)
    elseif deal.stage == "negotiation" then
        ProcessCrimeNegotiation(playerId, messageLower)
    end
end)

-- Process crime introduction
function ProcessCrimeIntroduction(playerId, message)
    local deal = activeDrugDeals[playerId]
    local npc = exports['npc-ai-voice']:GetNPCData(deal.npcId)
    
    -- Look for trust-building keywords
    if string.find(message, "confiance") or string.find(message, "discret") or string.find(message, "sérieux") then
        deal.trustLevel = deal.trustLevel + 20
    end
    
    if string.find(message, "argent") or string.find(message, "business") or string.find(message, "deal") then
        deal.trustLevel = deal.trustLevel + 15
    end
    
    -- Check for police/snitch keywords
    if string.find(message, "police") or string.find(message, "flic") or string.find(message, "balance") then
        deal.trustLevel = deal.trustLevel - 30
        local response = "J'aime pas ce genre de questions. Casse-toi d'ici."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
        activeDrugDeals[playerId] = nil
        return
    end
    
    -- Progress based on trust level
    if deal.trustLevel >= 50 then
        deal.stage = "business"
        local response = "D'accord... je pense qu'on peut faire affaire. Qu'est-ce qui vous intéresse ?"
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
    elseif deal.trustLevel <= -20 then
        local response = "Non, ça sent pas bon cette histoire. Dégage."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
        activeDrugDeals[playerId] = nil
    else
        local response = "Mmh... il faut que j'aie confiance. Continuez à parler."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
    end
end

-- Process crime business
function ProcessCrimeBusiness(playerId, message)
    local deal = activeDrugDeals[playerId]
    local availableDrugs = GetAvailableDrugs(deal.npcId)
    
    -- Check what drug the player is asking for
    local requestedDrug = nil
    for _, drug in pairs(availableDrugs) do
        if string.find(message, string.lower(drug.name)) then
            requestedDrug = drug
            break
        end
    end
    
    if requestedDrug then
        StartDrugNegotiation(playerId, requestedDrug)
    else
        -- List available drugs
        local response = "J'ai ça en stock : "
        for i, drug in pairs(availableDrugs) do
            response = response .. drug.name
            if i < #availableDrugs then
                response = response .. ", "
            end
        end
        response = response .. ". Qu'est-ce qui vous intéresse ?"
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
    end
end

-- Start drug negotiation
function StartDrugNegotiation(playerId, drug)
    local deal = activeDrugDeals[playerId]
    
    deal.stage = "negotiation"
    deal.selectedDrug = drug
    deal.quantity = 1
    deal.pricePerUnit = math.random(drug.price.min, drug.price.max)
    
    local response = "Pour le " .. drug.name .. ", c'est " .. deal.pricePerUnit .. "$ l'unité. Combien vous en voulez ?"
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
end

-- Process crime negotiation
function ProcessCrimeNegotiation(playerId, message)
    local deal = activeDrugDeals[playerId]
    
    -- Try to extract quantity from message
    local quantity = tonumber(string.match(message, "%d+"))
    
    if quantity then
        if quantity > 10 then
            local response = "Whoa, c'est beaucoup ça ! Je peux pas sortir autant d'un coup. Maximum 10 unités."
            TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
            return
        end
        
        deal.quantity = quantity
        local totalPrice = deal.quantity * deal.pricePerUnit
        
        local response = string.format("Donc %d unités de %s pour %d$. C'est bon pour vous ?", 
                                     deal.quantity, deal.selectedDrug.name, totalPrice)
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
        deal.stage = "confirmation"
    else
        local response = "Combien d'unités vous voulez ? Dites-moi un chiffre."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
    end
end

-- Confirm drug deal
RegisterNetEvent('npc-ai:confirmDrugDeal')
AddEventHandler('npc-ai:confirmDrugDeal', function(confirmed)
    local playerId = source
    local deal = activeDrugDeals[playerId]
    
    if not deal or deal.stage ~= "confirmation" then return end
    
    if confirmed then
        ExecuteDrugDeal(playerId)
    else
        local response = "Pas de problème. Revenez quand vous aurez décidé."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
        activeDrugDeals[playerId] = nil
    end
end)

-- Execute drug deal
function ExecuteDrugDeal(playerId)
    local deal = activeDrugDeals[playerId]
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    local totalPrice = deal.quantity * deal.pricePerUnit
    
    Utils.Debug("Executing drug deal for player " .. playerId .. ": " .. deal.quantity .. "x " .. deal.selectedDrug.name)
    
    -- Check if player has enough money (this would need integration with economy system)
    -- For now, assume the deal goes through
    
    -- Roll for police detection
    local detectionChance = Config.Crime.policeResponse.chanceToGetCaught
    local detected = math.random() < detectionChance
    
    if detected then
        TriggerPoliceAlert(playerId, deal)
        local response = "Merde ! Les flics ! Cassez-vous, vite !"
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
    else
        -- Successful deal
        local response = "Parfait. Voilà votre marchandise. Faites attention avec ça."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, deal.npcId, response)
        
        -- Give drugs to player (integrate with inventory system)
        TriggerClientEvent('npc-ai:receiveDrugs', playerId, deal.selectedDrug.name, deal.quantity)
        
        -- Update criminal reputation
        UpdateCriminalReputation(playerIdentifier, 5)
    end
    
    -- Save deal to database
    SaveCriminalActivity(playerIdentifier, deal, detected)
    
    -- Clean up
    activeDrugDeals[playerId] = nil
end

-- Trigger police alert
function TriggerPoliceAlert(playerId, deal)
    Utils.Debug("Police alert triggered for player " .. playerId)
    
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    
    policeAlerts[playerId] = {
        coords = playerCoords,
        crime = "drug_dealing",
        suspect = GetPlayerName(playerId),
        timestamp = os.time(),
        npcId = deal.npcId
    }
    
    -- Notify all police players
    TriggerClientEvent('npc-ai:policeAlert', -1, {
        type = "drug_dealing",
        location = playerCoords,
        suspect = GetPlayerName(playerId),
        description = "Trafic de drogue signalé"
    })
    
    -- Start police response
    Citizen.SetTimeout(30000, function() -- 30 seconds delay
        if policeAlerts[playerId] then
            ExecutePoliceResponse(playerId)
        end
    end)
end

-- Execute police response
function ExecutePoliceResponse(playerId)
    local alert = policeAlerts[playerId]
    if not alert then return end
    
    Utils.Debug("Executing police response for player " .. playerId)
    
    -- Apply penalties
    local penalty = Config.Crime.policeResponse.penalties.drugDealing
    
    -- Remove money (fine)
    TriggerClientEvent('npc-ai:applyFine', playerId, penalty.fine)
    
    -- Apply jail time
    if penalty.jailTime > 0 then
        TriggerClientEvent('npc-ai:sendToJail', playerId, penalty.jailTime)
    end
    
    -- Update criminal record
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    UpdateCriminalRecord(playerIdentifier, "drug_dealing", penalty)
    
    -- Notify player
    TriggerClientEvent('chat:addMessage', playerId, {
        template = '<div style="color: #F44336;"><b>Police:</b> Vous êtes arrêté pour trafic de drogue ! Amende: ' .. penalty.fine .. '$ | Prison: ' .. penalty.jailTime .. 's</div>',
        args = {}
    })
    
    -- Clean up
    policeAlerts[playerId] = nil
end

-- Get available drugs for NPC
function GetAvailableDrugs(npcId)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc or npc.personality ~= "criminal" then return {} end
    
    -- Return drugs from config
    return Config.Crime.drugDealing.drugs
end

-- Get player criminal reputation
function GetPlayerCriminalReputation(playerIdentifier)
    local result = MySQL.Sync.fetchScalar('SELECT SUM(reputation_change) as total_rep FROM criminal_activities WHERE player_identifier = ?', {
        playerIdentifier
    })
    
    return result or 0
end

-- Update criminal reputation
function UpdateCriminalReputation(playerIdentifier, change)
    -- This would typically be stored in a separate reputation table
    Utils.Debug("Updated criminal reputation for " .. playerIdentifier .. " by " .. change)
end

-- Update criminal record
function UpdateCriminalRecord(playerIdentifier, crimeType, penalty)
    local npcId = "system" -- System-generated record
    
    -- Add to NPC criminal records
    MySQL.Async.execute('INSERT INTO criminal_records (player_identifier, crime_type, penalty_fine, penalty_jail, created_at) VALUES (?, ?, ?, ?, ?)', {
        playerIdentifier,
        crimeType,
        penalty.fine,
        penalty.jailTime,
        os.time()
    }, function(affectedRows)
        if affectedRows > 0 then
            Utils.Debug("Added criminal record for " .. playerIdentifier)
        end
    end)
end

-- Save criminal activity
function SaveCriminalActivity(playerIdentifier, deal, detected)
    -- This would save to a criminal activities table
    Utils.Debug("Saved criminal activity for " .. playerIdentifier .. " - detected: " .. tostring(detected))
end

-- Check if player is in crime area
function IsPlayerInCrimeArea(playerCoords)
    for _, location in pairs(Config.Crime.drugDealing.locations) do
        local distance = #(playerCoords - location.coords)
        if distance <= location.radius then
            return true
        end
    end
    return false
end

-- Criminal network functions
function JoinCriminalNetwork(playerId, networkId)
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    
    if not criminalNetworks[networkId] then
        criminalNetworks[networkId] = {
            id = networkId,
            members = {},
            reputation = 0,
            activities = {}
        }
    end
    
    criminalNetworks[networkId].members[playerIdentifier] = {
        joinDate = os.time(),
        reputation = 0,
        rank = "associate"
    }
    
    Utils.Debug("Player " .. playerIdentifier .. " joined criminal network " .. networkId)
end

-- Cleanup expired deals and alerts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        local currentTime = os.time()
        
        -- Clean up old drug deals
        for playerId, deal in pairs(activeDrugDeals) do
            if currentTime - deal.startTime > 900 then -- 15 minutes timeout
                activeDrugDeals[playerId] = nil
                Utils.Debug("Cleaned up expired drug deal for player " .. playerId)
            end
        end
        
        -- Clean up old police alerts
        for playerId, alert in pairs(policeAlerts) do
            if currentTime - alert.timestamp > 300 then -- 5 minutes timeout
                policeAlerts[playerId] = nil
                Utils.Debug("Cleaned up expired police alert for player " .. playerId)
            end
        end
    end
end)

-- Command to check criminal stats
RegisterCommand('crime_stats', function(source, args, rawCommand)
    if source == 0 then return end -- Player only
    
    local playerId = source
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    local reputation = GetPlayerCriminalReputation(playerIdentifier)
    
    TriggerClientEvent('chat:addMessage', playerId, {
        template = '<div style="color: #F44336;"><b>Réputation criminelle:</b> ' .. reputation .. '</div>',
        args = {}
    })
    
    -- Show active deal if any
    if activeDrugDeals[playerId] then
        local deal = activeDrugDeals[playerId]
        TriggerClientEvent('chat:addMessage', playerId, {
            template = '<div style="color: #FF9800;"><b>Deal actif:</b> ' .. deal.stage .. ' avec NPC ' .. deal.npcId .. '</div>',
            args = {}
        })
    end
end, false)