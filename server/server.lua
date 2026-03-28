lib.locale()

local currentVersion = '1.0.1'
local versionURL = 'https://raw.githubusercontent.com/RuubTv/rtv-evidencelockers/main/version.txt'

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
            print('^3Download the latest version here: https://github.com/RuubTv/rtv-evidencelockers.git^0')
        else
            print('^2[rtv-evidence] You are running the latest version (' .. currentVersion .. ').^0')
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
    if not player or not player.PlayerData then
        return nil, 0
    end

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
        if job == playerJob then
            return true
        end
    end

    return false
end

local function hasWithdrawAccess(src, locker)
    local job, grade = getPlayerJobAndGrade(src)

    if not job or not hasJob(locker.jobs, job) then
        return false, locale('no_access_job')
    end

    local requiredGrade = locker.withdrawRank or locker.clearRank or 0
    if grade < requiredGrade then
        return false, locale('no_access_rank')
    end

    return true
end

local playerCooldowns = {}

RegisterNetEvent('rtv_evidence:create')
AddEventHandler('rtv_evidence:create', function(lockerName, name)
    local src = source
    local job = select(1, getPlayerJobAndGrade(src))
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    local stashName = generateStashName(name)

    if playerCooldowns[src] and (os.time() - playerCooldowns[src]) < 10 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('stash_wait')
        })
        return
    end

    playerCooldowns[src] = os.time()

    if #stashName < 5 or #stashName > 50 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('invalid_stash_name')
        })
        return
    end

    MySQL.scalar('SELECT stash_name FROM police_lockers WHERE stash_name = ?', { stashName }, function(result)
        if result then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = locale('stash_exists')
            })
        else
            MySQL.insert('INSERT INTO police_lockers (name, stash_name, locker) VALUES (?, ?, ?)', { name, stashName, lockerName }, function()
                exports.ox_inventory:RegisterStash(stashName, name, locker.stashSlots, locker.stashWeight, false)
                EvidenceStashes[stashName] = lockerName

                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'success',
                    description = locale('stash_created') .. ' ' .. name
                })
            end)
        end
    end)
end)

RegisterNetEvent('rtv_evidence:search')
AddEventHandler('rtv_evidence:search', function(lockerName, name)
    local src = source
    local job = select(1, getPlayerJobAndGrade(src))
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    local stashName = generateStashName(name)

    MySQL.scalar('SELECT stash_name FROM police_lockers WHERE stash_name = ? AND locker = ?', { stashName, lockerName }, function(result)
        if result then
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashName)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = locale('stash_not_found')
            })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:showAll')
AddEventHandler('rtv_evidence:showAll', function(lockerName)
    local src = source
    local job = select(1, getPlayerJobAndGrade(src))
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'info',
                description = locale('no_stashes')
            })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:clearMenu')
AddEventHandler('rtv_evidence:clearMenu', function(lockerName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_clear')
        })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openClearMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'info',
                description = locale('no_stashes')
            })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:confirmClear')
AddEventHandler('rtv_evidence:confirmClear', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_clear')
        })
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
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.clearRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_clear')
        })
        return
    end

    exports.ox_inventory:ClearInventory(stashName)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = locale('stash_cleared')
    })
end)

RegisterNetEvent('rtv_evidence:deleteMenu')
AddEventHandler('rtv_evidence:deleteMenu', function(lockerName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_delete')
        })
        return
    end

    MySQL.query('SELECT name, stash_name FROM police_lockers WHERE locker = ?', { lockerName }, function(results)
        if #results > 0 then
            TriggerClientEvent('rtv_evidence:openDeleteMenu', src, lockerName, results)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'info',
                description = locale('no_stashes')
            })
        end
    end)
end)

RegisterNetEvent('rtv_evidence:confirmDelete')
AddEventHandler('rtv_evidence:confirmDelete', function(lockerName, stashName)
    local src = source
    local job, grade = getPlayerJobAndGrade(src)
    local locker = Config.EvidenceLockers[lockerName]

    if not locker or not hasJob(locker.jobs, job) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_delete')
        })
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
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_job')
        })
        return
    end

    if grade < locker.deleteRank then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = locale('no_access_delete')
        })
        return
    end

    MySQL.execute('DELETE FROM police_lockers WHERE stash_name = ? AND locker = ?', { stashName, lockerName }, function(result)
        local affected = 0

        if type(result) == 'table' and result.affectedRows then
            affected = result.affectedRows
        elseif type(result) == 'number' then
            affected = result
        end

        if affected > 0 then
            exports.ox_inventory:ClearInventory(stashName)
            EvidenceStashes[stashName] = nil

            TriggerClientEvent('ox_lib:notify', src, {
                type = 'success',
                description = locale('stash_deleted')
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = locale('stash_not_found')
            })
        end
    end)
end)

-- Lage rangen:
-- - mogen kluizen openen en bekijken
-- - mogen alleen player -> stash naar een LEGE slot
-- - mogen NIET uit de kluis halen
-- - mogen NIET swappen of stacken richting de kluis
exports.ox_inventory:registerHook('swapItems', function(payload)
    local src = payload.source
    if not src then return end

    local fromInv  = payload.fromInventory
    local toInv    = payload.toInventory
    local fromType = payload.fromType
    local toType   = payload.toType
    local action   = payload.action

    local fromId = type(fromInv) == 'table' and fromInv.id or tostring(fromInv or '')
    local toId   = type(toInv)   == 'table' and toInv.id   or tostring(toInv   or '')

    local fromIsEvidence = EvidenceStashes[fromId] ~= nil
    local toIsEvidence   = EvidenceStashes[toId] ~= nil

    if not fromIsEvidence and not toIsEvidence then
        return
    end

    local lockerName = EvidenceStashes[fromId] or EvidenceStashes[toId]
    local locker = lockerName and Config.EvidenceLockers[lockerName]
    if not locker then return end

    local canWithdraw, denyMessage = hasWithdrawAccess(src, locker)

    -- Hoge rangen: normale ox_inventory flow
    if canWithdraw then
        return
    end

    -- Lage rangen mogen NOOIT iets UIT evidence halen
    if fromIsEvidence then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = denyMessage
        })
        return false
    end

    -- Lage rangen mogen alleen player -> stash
    if not (toIsEvidence and fromType == 'player' and toType == 'stash') then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Je mag alleen items in een lege slot van deze kluis plaatsen.'
        })
        return false
    end

    -- Swap of stack richting de kluis blokkeren
    if action == 'swap' or action == 'stack' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Je mag geen items vervangen of stapelen in deze kluis.'
        })
        return false
    end

    -- Als toSlot een table is, mikken ze op een bezet slot
    if type(payload.toSlot) == 'table' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Je mag alleen items in een lege slot van deze kluis plaatsen.'
        })
        return false
    end

    -- Alleen directe move naar een numerieke slot toestaan
    if action ~= 'move' or type(payload.toSlot) ~= 'number' then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Je mag alleen items in een lege slot van deze kluis plaatsen.'
        })
        return false
    end

    -- Extra server-check: doelslot moet echt leeg zijn
    local targetSlot = exports.ox_inventory:GetSlot(toId, payload.toSlot)
    if targetSlot and targetSlot.name then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Je mag alleen items in een lege slot van deze kluis plaatsen.'
        })
        return false
    end

    return
end)
