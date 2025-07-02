-- Database initialization
RegisterNetEvent('npc-ai:initDatabase')
AddEventHandler('npc-ai:initDatabase', function()
    Utils.Debug("Initializing database tables...")
    
    CreateNPCTables()
end)

-- Create all necessary database tables
function CreateNPCTables()
    -- NPCs table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.Database.table_npcs .. [[` (
            `id` VARCHAR(50) NOT NULL PRIMARY KEY,
            `name` VARCHAR(100) NOT NULL,
            `model` VARCHAR(50) NOT NULL DEFAULT 'a_m_y_business_01',
            `coords` TEXT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0.0,
            `personality` VARCHAR(50) NOT NULL DEFAULT 'friendly',
            `traits` TEXT,
            `backstory` TEXT,
            `job` VARCHAR(100),
            `criminal_record` TEXT,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function(success)
        if success then
            Utils.Debug("NPCs table created/verified")
        else
            Utils.Debug("Error creating NPCs table")
        end
    end)
    
    -- Conversations table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.Database.table_conversations .. [[` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `player_identifier` VARCHAR(50) NOT NULL,
            `npc_id` VARCHAR(50) NOT NULL,
            `context` LONGTEXT,
            `start_time` INT NOT NULL,
            `end_time` INT,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_player_npc` (`player_identifier`, `npc_id`),
            INDEX `idx_npc` (`npc_id`),
            FOREIGN KEY (`npc_id`) REFERENCES `]] .. Config.Database.table_npcs .. [[`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function(success)
        if success then
            Utils.Debug("Conversations table created/verified")
        else
            Utils.Debug("Error creating conversations table")
        end
    end)
    
    -- Memory table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.Database.table_memory .. [[` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `npc_id` VARCHAR(50) NOT NULL,
            `player_identifier` VARCHAR(50) NOT NULL,
            `content` TEXT NOT NULL,
            `importance` INT DEFAULT 5,
            `created_at` INT NOT NULL,
            INDEX `idx_npc_player` (`npc_id`, `player_identifier`),
            INDEX `idx_created_at` (`created_at`),
            FOREIGN KEY (`npc_id`) REFERENCES `]] .. Config.Database.table_npcs .. [[`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function(success)
        if success then
            Utils.Debug("Memory table created/verified")
        else
            Utils.Debug("Error creating memory table")
        end
    end)
    
    -- Jobs table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.Database.table_jobs .. [[` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `npc_id` VARCHAR(50) NOT NULL,
            `player_identifier` VARCHAR(50) NOT NULL,
            `company_name` VARCHAR(100) NOT NULL,
            `position` VARCHAR(100) NOT NULL,
            `status` ENUM('applied', 'interviewing', 'hired', 'rejected') DEFAULT 'applied',
            `application_data` TEXT,
            `interview_data` TEXT,
            `salary` INT,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_npc_player` (`npc_id`, `player_identifier`),
            INDEX `idx_status` (`status`),
            FOREIGN KEY (`npc_id`) REFERENCES `]] .. Config.Database.table_npcs .. [[`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {}, function(success)
        if success then
            Utils.Debug("Jobs table created/verified")
            CreateSampleNPCs()
        else
            Utils.Debug("Error creating jobs table")
        end
    end)
end

-- Create sample NPCs for testing
function CreateSampleNPCs()
    MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM ' .. Config.Database.table_npcs, {}, function(result)
        if result and result[1] and result[1].count == 0 then
            Utils.Debug("Creating sample NPCs...")
            CreateSampleNPCData()
        else
            Utils.Debug("NPCs already exist in database")
        end
    end)
end

-- Create sample NPC data
function CreateSampleNPCData()
    local sampleNPCs = {
        {
            id = "npc_clerk_01",
            name = "Marie Dubois",
            model = "a_f_y_business_01",
            coords = {x = -265.5, y = -720.8, z = 33.5},
            heading = 180.0,
            personality = "friendly",
            backstory = "Je travaille dans cette boutique depuis 5 ans. J'aime aider les clients et discuter de mode.",
            job = "Shop Clerk"
        },
        {
            id = "npc_mechanic_01", 
            name = "Jean Martin",
            model = "s_m_y_construct_01",
            coords = {x = -347.3, y = -133.6, z = 39.0},
            heading = 90.0,
            personality = "grumpy",
            backstory = "Je suis mécanicien depuis 20 ans. J'ai vu beaucoup de voitures passer par ici.",
            job = "Mechanic"
        },
        {
            id = "npc_criminal_01",
            name = "Tony Ricci",
            model = "g_m_m_armboss_01",
            coords = {x = 86.3, y = -1959.8, z = 21.1},
            heading = 270.0,
            personality = "criminal",
            backstory = "J'ai grandi dans les rues difficiles. Maintenant je connais tous les bons plans de la ville.",
            job = "Dealer"
        },
        {
            id = "npc_doctor_01",
            name = "Dr. Sophie Laurent",
            model = "s_f_y_scrubs_01",
            coords = {x = 294.1, y = -1448.5, z = 29.9},
            heading = 0.0,
            personality = "serious",
            backstory = "Je suis médecin urgentiste. Mon travail est de sauver des vies, peu importe les circonstances.",
            job = "Doctor"
        },
        {
            id = "npc_artist_01",
            name = "Lucas Petit",
            model = "a_m_y_hipster_01",
            coords = {x = -1159.4, y = -1425.7, z = 4.9},
            heading = 135.0,
            personality = "artist",
            backstory = "Je suis un artiste de rue. J'aime créer et partager ma passion avec les autres.",
            job = "Street Artist"
        }
    }
    
    for _, npcData in pairs(sampleNPCs) do
        npcData.traits = Utils.GeneratePersonalityTraits()
        npcData.criminal_record = {}
        
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
                Utils.Debug("Created sample NPC: " .. npcData.name)
            end
        end)
    end
end

-- Database maintenance functions
function CleanOldConversations()
    local cutoffTime = os.time() - (7 * 24 * 60 * 60) -- 7 days ago
    
    MySQL.Async.execute('DELETE FROM ' .. Config.Database.table_conversations .. ' WHERE start_time < ?', {
        cutoffTime
    }, function(affectedRows)
        if affectedRows > 0 then
            Utils.Debug("Cleaned " .. affectedRows .. " old conversations")
        end
    end)
end

function CleanOldMemories()
    local cutoffTime = os.time() - (Config.NPCs.memoryDuration / 1000)
    
    MySQL.Async.execute('DELETE FROM ' .. Config.Database.table_memory .. ' WHERE created_at < ?', {
        cutoffTime
    }, function(affectedRows)
        if affectedRows > 0 then
            Utils.Debug("Cleaned " .. affectedRows .. " old memories")
        end
    end)
end

-- Run maintenance tasks periodically
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600000) -- Every hour
        
        CleanOldConversations()
        CleanOldMemories()
    end
end)

-- Get NPC statistics
RegisterCommand('npc_stats', function(source, args, rawCommand)
    if source ~= 0 then return end -- Console only
    
    MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM ' .. Config.Database.table_npcs, {}, function(npcs)
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM ' .. Config.Database.table_conversations, {}, function(conversations)
            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM ' .. Config.Database.table_memory, {}, function(memories)
                MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM ' .. Config.Database.table_jobs, {}, function(jobs)
                    Utils.Debug("=== NPC AI Statistics ===")
                    Utils.Debug("NPCs: " .. (npcs[1] and npcs[1].count or 0))
                    Utils.Debug("Conversations: " .. (conversations[1] and conversations[1].count or 0))
                    Utils.Debug("Memories: " .. (memories[1] and memories[1].count or 0))
                    Utils.Debug("Job Applications: " .. (jobs[1] and jobs[1].count or 0))
                    Utils.Debug("========================")
                end)
            end)
        end)
    end)
end, true)

-- Create new NPC via command
RegisterCommand('create_npc', function(source, args, rawCommand)
    if source == 0 then return end -- Player only
    
    local playerId = source
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', playerId, {
            template = '<div style="color: red;"><b>Usage:</b> /create_npc [name] [personality]</div>',
            args = {}
        })
        return
    end
    
    local name = args[1]
    local personality = args[2]
    
    if not table.contains(Config.NPCs.personalities, personality) then
        TriggerClientEvent('chat:addMessage', playerId, {
            template = '<div style="color: red;"><b>Error:</b> Invalid personality. Valid options: ' .. table.concat(Config.NPCs.personalities, ', ') .. '</div>',
            args = {}
        })
        return
    end
    
    local npcData = {
        name = name,
        model = 'a_m_y_business_01',
        coords = {x = playerCoords.x + 2.0, y = playerCoords.y, z = playerCoords.z},
        heading = playerHeading,
        personality = personality
    }
    
    local npcId = exports['npc-ai-voice']:CreateNPC(npcData)
    
    TriggerClientEvent('chat:addMessage', playerId, {
        template = '<div style="color: green;"><b>Success:</b> Created NPC "' .. name .. '" with ID: ' .. npcId .. '</div>',
        args = {}
    })
end, false)

-- Helper function to check if table contains value
function table.contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end