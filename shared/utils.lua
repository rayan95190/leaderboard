Utils = {}

-- Debug logging
function Utils.Debug(message)
    if Config.Debug then
        print(string.format("[NPC-AI] %s", message))
    end
end

-- Generate unique identifier
function Utils.GenerateId()
    return string.format("%s-%s", GetGameTimer(), math.random(10000, 99999))
end

-- Distance calculation
function Utils.GetDistance(pos1, pos2)
    return #(pos1 - pos2)
end

-- Random selection from table
function Utils.GetRandomFromTable(tbl)
    if #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

-- Check if player is in vehicle
function Utils.IsPlayerInVehicle(playerId)
    return IsPedInAnyVehicle(GetPlayerPed(playerId), false)
end

-- Format time
function Utils.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Validate coordinates
function Utils.IsValidCoords(coords)
    return coords and coords.x and coords.y and coords.z
end

-- Generate random personality traits
function Utils.GeneratePersonalityTraits()
    local traits = {
        openness = math.random(1, 10),
        conscientiousness = math.random(1, 10),
        extraversion = math.random(1, 10),
        agreeableness = math.random(1, 10),
        neuroticism = math.random(1, 10)
    }
    return traits
end

-- Clean string for AI processing
function Utils.CleanString(str)
    if not str then return "" end
    -- Remove special characters that might interfere with AI processing
    return string.gsub(str, "[%c%z]", "")
end

-- Generate NPC backstory based on personality
function Utils.GenerateBackstory(personality, traits)
    local backstories = {
        friendly = "Je suis quelqu'un de très sociable qui aime rencontrer de nouvelles personnes.",
        grumpy = "J'ai eu une vie difficile et je n'ai pas beaucoup de patience pour les gens.",
        mysterious = "Mon passé est complexe et je préfère garder certaines choses pour moi.",
        cheerful = "J'essaie toujours de voir le bon côté des choses et de rendre les autres heureux.",
        serious = "Je prends la vie au sérieux et j'aime que les choses soient faites correctement.",
        criminal = "J'ai eu des démêlés avec la loi et je connais bien les rues de cette ville.",
        businessman = "Je travaille dans le commerce et j'ai toujours un œil sur les opportunités.",
        artist = "Je suis passionné par l'art et la créativité sous toutes ses formes.",
        worker = "Je travaille dur pour gagner ma vie et j'ai de l'expérience dans plusieurs domaines.",
        student = "J'étudie encore et j'essaie d'apprendre autant que possible sur le monde."
    }
    
    return backstories[personality] or "Je suis une personne ordinaire avec ma propre histoire."
end