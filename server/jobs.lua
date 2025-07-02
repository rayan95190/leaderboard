-- Job system for NPCs
local jobApplications = {}
local activeInterviews = {}

-- Initialize job system
RegisterNetEvent('npc-ai:initiateJobDiscussion')
AddEventHandler('npc-ai:initiateJobDiscussion', function(npcId, playerId)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc then return end
    
    Utils.Debug("Initiating job discussion between player " .. playerId .. " and NPC " .. npc.name)
    
    -- Check if NPC is in position to help with jobs
    if npc.job and (string.find(string.lower(npc.job), "manager") or string.find(string.lower(npc.job), "hr") or npc.personality == "businessman") then
        StartJobDiscussion(npcId, playerId)
    else
        -- NPC can provide job information but not hire
        ProvideJobInformation(npcId, playerId)
    end
end)

-- Start job discussion
function StartJobDiscussion(npcId, playerId)
    local availableJobs = GetAvailableJobsForNPC(npcId)
    
    if #availableJobs == 0 then
        local response = "Désolé, nous n'avons pas d'ouvertures en ce moment. Revenez plus tard."
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
        return
    end
    
    -- Generate job offer response
    local response = "Nous avons quelques postes disponibles. "
    for i, job in pairs(availableJobs) do
        response = response .. job.position .. " chez " .. job.name
        if i < #availableJobs then
            response = response .. ", "
        end
    end
    response = response .. ". Quel poste vous intéresse ?"
    
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
    
    -- Store job discussion state
    jobApplications[playerId] = {
        npcId = npcId,
        availableJobs = availableJobs,
        stage = "job_selection",
        startTime = os.time()
    }
end

-- Provide job information
function ProvideJobInformation(npcId, playerId)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    local response = ""
    
    if npc.job then
        response = "Je travaille comme " .. npc.job .. ". "
    end
    
    response = response .. "Pour trouver du travail, vous devriez aller voir les managers dans les entreprises locales. "
    response = response .. "Il y a des opportunités chez les taxis, l'hôpital, la police, et d'autres endroits."
    
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
end

-- Get available jobs for specific NPC
function GetAvailableJobsForNPC(npcId)
    local npc = exports['npc-ai-voice']:GetNPCData(npcId)
    if not npc or not npc.job then return {} end
    
    local availableJobs = {}
    
    -- Match NPC job with company types
    for _, company in pairs(Config.Jobs.companies) do
        if ShouldNPCOfferJob(npc, company) then
            table.insert(availableJobs, company)
        end
    end
    
    return availableJobs
end

-- Check if NPC should offer job from company
function ShouldNPCOfferJob(npc, company)
    -- Business personality can offer any job
    if npc.personality == "businessman" then return true end
    
    -- Match job types
    if npc.job then
        local jobLower = string.lower(npc.job)
        local companyType = string.lower(company.type)
        
        if string.find(jobLower, "manager") or string.find(jobLower, "hr") then
            return true
        end
        
        if string.find(jobLower, companyType) then
            return true
        end
        
        -- Specific matches
        if string.find(jobLower, "doctor") and company.type == "medical" then return true end
        if string.find(jobLower, "police") and company.type == "government" then return true end
        if string.find(jobLower, "taxi") and company.type == "transport" then return true end
    end
    
    return false
end

-- Process job application
RegisterNetEvent('npc-ai:processJobApplication')
AddEventHandler('npc-ai:processJobApplication', function(jobChoice, playerData)
    local playerId = source
    local application = jobApplications[playerId]
    
    if not application then
        Utils.Debug("No active job application for player " .. playerId)
        return
    end
    
    local selectedJob = nil
    for _, job in pairs(application.availableJobs) do
        if string.find(string.lower(job.name), string.lower(jobChoice)) or 
           string.find(string.lower(job.positions[1]), string.lower(jobChoice)) then
            selectedJob = job
            break
        end
    end
    
    if not selectedJob then
        local response = "Je ne suis pas sûr de quel poste vous parlez. Pouvez-vous être plus précis ?"
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, application.npcId, response)
        return
    end
    
    -- Start interview process
    StartJobInterview(playerId, application.npcId, selectedJob)
end)

-- Start job interview
function StartJobInterview(playerId, npcId, job)
    Utils.Debug("Starting job interview for player " .. playerId)
    
    activeInterviews[playerId] = {
        npcId = npcId,
        job = job,
        stage = "interview",
        currentQuestion = 1,
        answers = {},
        startTime = os.time()
    }
    
    -- Clear job application
    jobApplications[playerId] = nil
    
    -- Send first interview question
    local firstQuestion = Config.Jobs.interviewQuestions[1]
    local response = "Parfait ! Commençons l'entretien pour le poste de " .. job.positions[1] .. 
                    " chez " .. job.name .. ". " .. firstQuestion
    
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, npcId, response)
end

-- Process interview answer
RegisterNetEvent('npc-ai:processInterviewAnswer')
AddEventHandler('npc-ai:processInterviewAnswer', function(answer)
    local playerId = source
    local interview = activeInterviews[playerId]
    
    if not interview then
        Utils.Debug("No active interview for player " .. playerId)
        return
    end
    
    -- Store answer
    interview.answers[interview.currentQuestion] = {
        question = Config.Jobs.interviewQuestions[interview.currentQuestion],
        answer = answer,
        timestamp = os.time()
    }
    
    -- Move to next question or finish interview
    interview.currentQuestion = interview.currentQuestion + 1
    
    if interview.currentQuestion <= #Config.Jobs.interviewQuestions then
        -- Ask next question
        local nextQuestion = Config.Jobs.interviewQuestions[interview.currentQuestion]
        local response = "Intéressant. " .. nextQuestion
        TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, interview.npcId, response)
    else
        -- Finish interview
        FinishJobInterview(playerId)
    end
end)

-- Finish job interview
function FinishJobInterview(playerId)
    local interview = activeInterviews[playerId]
    if not interview then return end
    
    Utils.Debug("Finishing job interview for player " .. playerId)
    
    -- Evaluate interview
    local score = EvaluateInterviewAnswers(interview.answers)
    local hired = score >= 70 -- 70% threshold
    
    -- Save to database
    SaveJobApplication(playerId, interview, hired, score)
    
    -- Generate response
    local response = ""
    if hired then
        response = "Félicitations ! Nous sommes heureux de vous offrir le poste de " .. 
                  interview.job.positions[1] .. " chez " .. interview.job.name .. 
                  ". Votre salaire sera de " .. math.random(interview.job.salary.min, interview.job.salary.max) .. 
                  "$ par mois. Bienvenue dans l'équipe !"
    else
        response = "Merci pour votre temps. Malheureusement, nous avons décidé de ne pas aller de l'avant avec votre candidature. " ..
                  "N'hésitez pas à postuler à nouveau dans le futur."
    end
    
    TriggerClientEvent('npc-ai:receiveNPCResponse', playerId, interview.npcId, response)
    
    -- Trigger job result event
    TriggerClientEvent('npc-ai:jobInterviewResult', playerId, hired, interview.job)
    
    -- Clean up
    activeInterviews[playerId] = nil
end

-- Evaluate interview answers
function EvaluateInterviewAnswers(answers)
    local totalScore = 0
    local maxScore = #answers * 25 -- 25 points per question
    
    for _, answer in pairs(answers) do
        local score = EvaluateAnswer(answer.question, answer.answer)
        totalScore = totalScore + score
    end
    
    return math.floor((totalScore / maxScore) * 100)
end

-- Evaluate individual answer
function EvaluateAnswer(question, answer)
    local score = 10 -- Base score
    local answerLower = string.lower(answer)
    
    -- Positive keywords
    local positiveKeywords = {
        "expérience", "motivé", "équipe", "responsable", "professionnel",
        "apprendre", "développer", "objectif", "qualité", "service"
    }
    
    -- Negative keywords
    local negativeKeywords = {
        "ennuyeux", "difficile", "problème", "pas", "jamais", "impossible"
    }
    
    -- Check for positive keywords
    for _, keyword in pairs(positiveKeywords) do
        if string.find(answerLower, keyword) then
            score = score + 3
        end
    end
    
    -- Check for negative keywords
    for _, keyword in pairs(negativeKeywords) do
        if string.find(answerLower, keyword) then
            score = score - 2
        end
    end
    
    -- Length bonus (detailed answers are better)
    if string.len(answer) > 50 then
        score = score + 2
    end
    
    -- Cap the score
    return math.max(0, math.min(25, score))
end

-- Save job application to database
function SaveJobApplication(playerId, interview, hired, score)
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    
    MySQL.Async.execute('INSERT INTO ' .. Config.Database.table_jobs .. ' (npc_id, player_identifier, company_name, position, status, application_data, interview_data, salary) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        interview.npcId,
        playerIdentifier,
        interview.job.name,
        interview.job.positions[1],
        hired and 'hired' or 'rejected',
        json.encode({
            job = interview.job,
            applicationTime = interview.startTime
        }),
        json.encode({
            answers = interview.answers,
            score = score,
            interviewTime = os.time()
        }),
        hired and math.random(interview.job.salary.min, interview.job.salary.max) or nil
    })
    
    Utils.Debug("Saved job application for player " .. playerId .. " - " .. (hired and "HIRED" or "REJECTED"))
end

-- Get player job history
function GetPlayerJobHistory(playerIdentifier)
    return MySQL.Sync.fetchAll('SELECT * FROM ' .. Config.Database.table_jobs .. ' WHERE player_identifier = ? ORDER BY created_at DESC', {
        playerIdentifier
    })
end

-- Check if player has job with company
function PlayerHasJobWithCompany(playerIdentifier, companyName)
    local result = MySQL.Sync.fetchAll('SELECT * FROM ' .. Config.Database.table_jobs .. ' WHERE player_identifier = ? AND company_name = ? AND status = "hired" ORDER BY created_at DESC LIMIT 1', {
        playerIdentifier, companyName
    })
    
    return result and #result > 0
end

-- Timeout cleanup for applications and interviews
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        local currentTime = os.time()
        
        -- Clean up old job applications
        for playerId, application in pairs(jobApplications) do
            if currentTime - application.startTime > 600 then -- 10 minutes timeout
                jobApplications[playerId] = nil
                Utils.Debug("Cleaned up expired job application for player " .. playerId)
            end
        end
        
        -- Clean up old interviews
        for playerId, interview in pairs(activeInterviews) do
            if currentTime - interview.startTime > 1200 then -- 20 minutes timeout
                activeInterviews[playerId] = nil
                Utils.Debug("Cleaned up expired interview for player " .. playerId)
            end
        end
    end
end)

-- Command to check job stats
RegisterCommand('job_stats', function(source, args, rawCommand)
    if source == 0 then return end -- Player only
    
    local playerId = source
    local playerIdentifier = GetPlayerIdentifier(playerId, 0)
    local jobHistory = GetPlayerJobHistory(playerIdentifier)
    
    TriggerClientEvent('chat:addMessage', playerId, {
        template = '<div style="color: #4CAF50;"><b>Historique de vos candidatures:</b></div>',
        args = {}
    })
    
    if #jobHistory == 0 then
        TriggerClientEvent('chat:addMessage', playerId, {
            template = '<div style="color: #FFC107;">Aucune candidature trouvée.</div>',
            args = {}
        })
    else
        for _, job in pairs(jobHistory) do
            local statusColor = job.status == 'hired' and '#4CAF50' or '#F44336'
            TriggerClientEvent('chat:addMessage', playerId, {
                template = '<div style="color: ' .. statusColor .. ';">' .. job.position .. ' chez ' .. job.company_name .. ' - ' .. job.status .. '</div>',
                args = {}
            })
        end
    end
end, false)