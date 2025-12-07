lib.locale()

local currentVersion = '1.0.0'
local versionURL = 'https://github.com/RuubTv/rtv-evidencelockers/blob/main/version.txt'
local EvidenceStashes = {}


local RankMap = {
    police = function(grade)
        return grade
    end,

    bcso = function(grade)
        if grade == 6 then return 7 end 
        return grade
    end,

    fib = function(grade)
        if grade == 0 then return 8 end 
        return grade
    end,

    da = function(grade)
        if grade == 0 then return 8 end 
        return grade
    end,

    mcu = function(grade)
        if grade == 0 then return 7 end  
        if grade == 1 then return 8 end  
        if grade == 2 then return 9 end  
        if grade == 3 then return 11 end 
        return grade
    end,
}

CreateThread(function()
    PerformHttpRequest(versionURL, function(status, response, _)
        if not response or status ~= 200 then
            print('^1[rtv-evidence] Version check failed. Could not reach version server.^0')
            return
        end

        local latestVersion = response:gsub('%s+', '')
        if latestVersion ~= currentVersion then
            print('^3[rtv-evidence] A new version is available: ^2' .. latestVersion .. '^3 (You are running: ^1' .. currentVersion .. '^3)')
            print('^3Download the latest version here: https://github.com/RuubTv/rtv-evidencelockers.git)
        else
            print('^2[rtv-evidence] You are running the latest version (' .. currentVersion .. ').^0'))
        end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    MySQL.query('SELECT stash_name, name, locker FROM police_lockers', {}, function(results)
        if results and #results > 0 then
            for _, stash in ipairs(results) do
                local locker = Config.EvidenceLockers[stash.locker]
                local slots = locker and locker.stashSlots or 20
                local weight = locker and locker.stashWeight or 500000

                exports.ox_inventory:RegisterStash(stash.stash_name, stash.name, slots, weight, false)

                EvidenceStashes[stash.stash_name] = stash.locker
            end
            print('^2[rtv-evidence] Loaded ' .. #results .. ' evidence lockers from database.^0')
        else
            print('^3[rtv-evidence] No evidence lockers found in database.^0')
        end
    end)
end)

local function generateStashName(name)
    local cleanedName = name:gsub("%s+", "_"):gsub("[^%w_]", ""):lower()
    return 'police_locker_' .. cleanedName
end

local function getPlayerJobAndGrade(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData then return nil, 0 end

    local job = player.PlayerData.job and player.PlayerData.job.name or nil
    local grade = player.PlayerData.job and (player.PlayerData.job.grade.level or player.PlayerData.job.grade) or 0


    local mapper = job and RankMap[job]
    if mapper then
        local mapped = mapper(grade)
        if mapped ~= nil then
            grade = mapped
        end
    end

    return job, grade
end

local function hasJob(jobs, playerJob)
    for _, job in ipairs(jobs) do
        if job == playerJob then return true end
    end
    return false
end

local playerCooldowns = {}

-- =========================
-- RTV EVENTS
-- =========================

RegisterNetEvent('rtv_evidence:create')
AddEventHandler('rtv_evidence:create', function(lockerName, name)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end

    local stashName = generateStashName(name)

    if playerCooldowns[src] and (os.time() - playerCooldowns[src]) < 10 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('stash_wait') })
        return
    end

    playerCooldowns[src] = os.time()

    if #stashName < 5 or #stashName > 50 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('invalid_stash_name') })
        return
    end

    MySQL.scalar('SELECT stash_name FROM police_lockers WHERE stash_name = ?', { stashName }, function(result)
        if result then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('stash_exists') })
        else
            MySQL.insert('INSERT INTO police_lockers (name, stash_name, locker) VALUES (?, ?, ?)', { name, stashName, lockerName }, function()
                exports.ox_inventory:RegisterStash(stashName, name, locker.stashSlots, locker.stashWeight, false)

                EvidenceStashes[stashName] = lockerName

                TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('stash_created') .. ' ' .. name })
            end)
        end
    end)
end)

RegisterNetEvent('rtv_evidence:search')
AddEventHandler('rtv_evidence:search', function(lockerName, name)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end

    local stashName = generateStashName(name)

    MySQL.scalar('SELECT stash_name FROM police_lockers WHERE stash_name = ? AND locker = ?', { stashName, lockerName }, function(result)
        if result then
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashName)
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('stash_not_found') })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:showAll')
AddEventHandler('rtv_evidence:showAll', function(lockerName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = locale('no_stashes') })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:clearMenu')
AddEventHandler('rtv_evidence:clearMenu', function(lockerName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_clear') })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openClearMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = locale('no_stashes') })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:confirmClear')
AddEventHandler('rtv_evidence:confirmClear', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_clear') })
        return
    end

    TriggerClientEvent('rtv_evidence:confirmClear', src, lockerName, stashName)
end)

RegisterNetEvent('rtv_evidence:clear')
AddEventHandler('rtv_evidence:clear', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_clear') })
        return
    end

    exports.ox_inventory:ClearInventory(stashName)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('stash_cleared') })
end)

RegisterNetEvent('rtv_evidence:deleteMenu')
AddEventHandler('rtv_evidence:deleteMenu', function(lockerName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_delete') })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openDeleteMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = locale('no_stashes') })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:confirmDelete')
AddEventHandler('rtv_evidence:confirmDelete', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_delete') })
        return
    end

    TriggerClientEvent('rtv_evidence:confirmDelete', src, lockerName, stashName)
end)

RegisterNetEvent('rtv_evidence:delete')
AddEventHandler('rtv_evidence:delete', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]
    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_job') })
        return
    end
    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('no_access_delete') })
        return
    end

    MySQL.execute('DELETE FROM police_lockers WHERE stash_name = ? AND locker = ?', { stashName, lockerName }, function(affected)
        if affected > 0 then
            exports.ox_inventory:ClearInventory(stashName)
            EvidenceStashes[stashName] = nil
            TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('stash_deleted') })
        else
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('stash_not_found') })
        end
    end)
end)

-- =========================
-- WITHDRAW BLOCK HOOK
-- =========================

exports.ox_inventory:registerHook('swapItems', function(payload)
    local src = payload.source
    if not src then return end

    local fromInv  = payload.fromInventory
    local toInv    = payload.toInventory
    local fromType = payload.fromType
    local toType   = payload.toType

    local fromId = type(fromInv) == 'table' and fromInv.id or tostring(fromInv or '')
    local toId   = type(toInv)   == 'table' and toInv.id   or tostring(toInv   or '')

    local stashName, action


    if EvidenceStashes[fromId] and fromType == 'stash' and toType == 'player' then
        stashName = fromId
        action = 'withdraw'


    elseif EvidenceStashes[toId] and fromType == 'player' and toType == 'stash' then
        stashName = toId
        action = 'deposit'
    else
        return
    end

    local lockerName = EvidenceStashes[stashName]
    local locker = lockerName and Config.EvidenceLockers[lockerName]
    if not locker then return end


    if action == 'withdraw' then
        local job, grade = getPlayerJobAndGrade(src)

        if not job or not hasJob(locker.jobs, job) then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = locale('no_access_job')
            })
            return false
        end

        local requiredGrade = locker.withdrawRank or locker.clearRank or 0
        if grade < requiredGrade then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = locale('no_access_rank')
            })
            return false
        end
    end
end, {
    inventoryFilter = { '^police_locker_' },
    typeFilter      = { stash = true }
})
