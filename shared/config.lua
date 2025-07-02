Config = {}

-- General settings
Config.Debug = true
Config.Locale = 'fr'

-- Voice system settings
Config.Voice = {
    enabled = true,
    proximityDistance = 15.0,
    autoActivation = true,
    speechToText = {
        enabled = true,
        language = 'fr-FR',
        apiEndpoint = 'http://localhost:3000/speech-to-text'
    },
    textToSpeech = {
        enabled = true,
        voice = 'fr-FR-Standard-A',
        apiEndpoint = 'http://localhost:3000/text-to-speech'
    }
}

-- AI settings
Config.AI = {
    enabled = true,
    provider = 'ollama',
    endpoint = 'http://localhost:11434',
    model = 'llama3.2',
    contextLength = 4096,
    temperature = 0.7,
    systemPrompt = "Tu es un NPC dans une ville de FiveM. Tu as une personnalité unique et tu peux avoir des conversations naturelles avec les joueurs. Réponds de manière cohérente avec ton rôle et ta personnalité."
}

-- NPC settings
Config.NPCs = {
    maxActiveNPCs = 50,
    spawnDistance = 100.0,
    despawnDistance = 150.0,
    conversationTimeout = 300000, -- 5 minutes
    memoryDuration = 7200000, -- 2 hours
    personalities = {
        'friendly', 'grumpy', 'mysterious', 'cheerful', 'serious', 
        'criminal', 'businessman', 'artist', 'worker', 'student'
    }
}

-- Job system
Config.Jobs = {
    enabled = true,
    companies = {
        {
            name = "Taxi Company",
            type = "transport",
            positions = {"driver", "dispatcher"},
            requirements = {"clean_record"},
            salary = {min = 2000, max = 4000}
        },
        {
            name = "Police Department", 
            type = "government",
            positions = {"officer", "detective"},
            requirements = {"clean_record", "physical_test"},
            salary = {min = 3000, max = 6000}
        },
        {
            name = "Hospital",
            type = "medical",
            positions = {"doctor", "nurse", "paramedic"},
            requirements = {"medical_degree", "clean_record"},
            salary = {min = 4000, max = 8000}
        }
    },
    interviewQuestions = {
        "Pourquoi voulez-vous travailler ici?",
        "Quelles sont vos expériences précédentes?",
        "Comment gérez-vous le stress?",
        "Quels sont vos objectifs professionnels?"
    }
}

-- Crime system
Config.Crime = {
    enabled = true,
    drugDealing = {
        enabled = true,
        locations = {
            {coords = vector3(123.45, -678.90, 30.0), radius = 50.0},
            {coords = vector3(456.78, -123.45, 25.0), radius = 50.0}
        },
        drugs = {
            {name = "weed", price = {min = 50, max = 100}},
            {name = "cocaine", price = {min = 200, max = 400}}
        }
    },
    policeResponse = {
        enabled = true,
        chanceToGetCaught = 0.2,
        penalties = {
            drugDealing = {fine = 5000, jailTime = 300},
            violence = {fine = 2000, jailTime = 180}
        }
    }
}

-- Database settings
Config.Database = {
    table_npcs = 'npc_ai_characters',
    table_conversations = 'npc_ai_conversations',
    table_memory = 'npc_ai_memory',
    table_jobs = 'npc_ai_jobs'
}