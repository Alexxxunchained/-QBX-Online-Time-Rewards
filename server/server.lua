local QBCore = exports['qb-core']:GetCoreObject()

local function InitializeDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sponsor_balance (
            citizenid VARCHAR(50) PRIMARY KEY,
            balance INT DEFAULT 0
        )
    ]])

    -- 保持原有的表创建
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]]..Config.DatabaseTables.rewards..[[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50),
            amount INT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ]]..Config.DatabaseTables.purchases..[[ (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50),
            item_name VARCHAR(50),
            item_type VARCHAR(20),
            price INT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end

local function RecordReward(identifier, amount)
    MySQL.insert('INSERT INTO '..Config.DatabaseTables.rewards..' (identifier, amount) VALUES (?, ?)',
        {identifier, amount})
end

local function RecordPurchase(identifier, itemName, itemType, price)
    MySQL.insert('INSERT INTO '..Config.DatabaseTables.purchases..' (identifier, item_name, item_type, price) VALUES (?, ?, ?, ?)',
        {identifier, itemName, itemType, price})
end

local function GetBalance(citizenid)
    local result = MySQL.scalar.await('SELECT balance FROM sponsor_balance WHERE citizenid = ?', {citizenid})
    return result or 0
end

local function UpdateBalance(citizenid, amount)
    MySQL.query.await([[
        INSERT INTO sponsor_balance (citizenid, balance) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE balance = balance + ?
    ]], {citizenid, amount, amount})
end

RegisterNetEvent('sponsor:purchaseItem', function(itemName, itemType, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local balance = GetBalance(Player.PlayerData.citizenid)
    if balance < price then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '错误', -- 'Error'
            description = '赞助币不足！', -- 'Insufficient coins!'
            type = 'error'
        })
        return
    end

    UpdateBalance(Player.PlayerData.citizenid, -price)

    if itemType == 'vehicle' then
        local plate = GeneratePlate()
        -- 来自givecar的snippet
        local vehicleData = {
            model = itemName,
            plate = plate,
            garage = "pillboxgarage",
            state = 1,
            mods = '{}'
        }
        
        MySQL.insert('INSERT INTO player_vehicles (citizenid, license, hash, plate, vehicle, mods, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            {
                Player.PlayerData.citizenid,
                Player.PlayerData.license,
                GetHashKey(vehicleData.model),
                plate,
                vehicleData.model,
                vehicleData.mods,
                vehicleData.garage,
                vehicleData.state
            }, function(id)
                if id then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '购买成功', -- 'Purchase Successful'
                        description = '车辆已存入车库', -- 'Vehicle stored in garage'
                        type = 'success'
                    })
                else
                    UpdateBalance(Player.PlayerData.citizenid, price)
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '错误', -- 'Error'
                        description = '购买失败，赞助币已退还', -- 'Purchase failed, coins refunded'
                        type = 'error'
                    })
                end
            end)
    else
        exports.ox_inventory:AddItem(src, itemName, 1)
        TriggerClientEvent('ox_lib:notify', src, {
            title = '购买成功', -- 'Purchase Successful'
            description = '成功购买 ' .. itemName, -- 'Successfully purchased %s'
            type = 'success'
        })
    end

    RecordPurchase(Player.PlayerData.citizenid, itemName, itemType, price)
end)

lib.callback.register('sponsor:getPurchaseHistory', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    local result = MySQL.query.await([[
        SELECT 
            p.*,
            DATE_FORMAT(p.timestamp, '%Y-%m-%d %H:%i:%s') as formatted_time
        FROM ]]..Config.DatabaseTables.purchases..[[ p
        WHERE identifier = ?
    ]], {Player.PlayerData.citizenid})
    return result
end)

-- 获取所有历史记录（管理员端） For admin check history
lib.callback.register('sponsor:getAllHistory', function(source)
    -- 检查是否有admin权限
    if IsPlayerAceAllowed(source, "admin") then
        local rewards = MySQL.query.await([[
            SELECT 
                r.*,
                DATE_FORMAT(r.timestamp, '%Y-%m-%d %H:%i:%s') as formatted_time
            FROM ]]..Config.DatabaseTables.rewards..[[ r
        ]])
        
        local purchases = MySQL.query.await([[
            SELECT 
                p.*,
                DATE_FORMAT(p.timestamp, '%Y-%m-%d %H:%i:%s') as formatted_time
            FROM ]]..Config.DatabaseTables.purchases..[[ p
        ]])
        
        return {rewards = rewards, purchases = purchases}
    end
    return false
end)

lib.callback.register('sponsor:checkAdmin', function(source)
    return IsPlayerAceAllowed(source, "admin")
end)

CreateThread(function()
    while true do
        Wait(Config.OnlineRewardInterval * 60 * 1000)
        local Players = QBCore.Functions.GetPlayers()
        for _, playerId in pairs(Players) do
            local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
            if Player then
                UpdateBalance(Player.PlayerData.citizenid, 1)
                RecordReward(Player.PlayerData.citizenid, 1)
                TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, {
                    title = '在线奖励', -- 'Online Reward'
                    description = '你获得了1个赞助币！', -- 'You have received 1 coin!'
                    type = 'success'
                })
            end
        end
    end
end)

-- 生成车牌号 这里你可以自己改一下你想要的车牌号格式 RandomStr(3)是指3个字符 也就是字母  QBCore.Shared.RandomInt(3)是指3个数字
-- Generate plate number 
function GeneratePlate()
    local plate = QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(3)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    end
    return plate
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        InitializeDatabase()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then
    return
  end

end)

lib.callback.register('sponsor:getBalance', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return GetBalance(Player.PlayerData.citizenid)
end)

-- 管理员指令 For admin command use 
QBCore.Commands.Add('givezzb', '给予玩家赞助币', {{name = 'id', help = '玩家ID'}, {name = 'amount', help = '数量'}}, true, function(source, args)
    if not IsPlayerAceAllowed(source, "admin") then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- 'Error'
            description = '你没有权限使用此命令', -- 'You do not have permission to use this command'
            type = 'error'
        })
        return
    end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- 'Error'
            description = '参数错误', -- 'Invalid parameters'
            type = 'error'
        })
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- 'Error'
            description = '找不到该玩家', -- 'Player not found'
            type = 'error'
        })
        return
    end

    UpdateBalance(targetPlayer.PlayerData.citizenid, amount)
    
    RecordReward(targetPlayer.PlayerData.citizenid, amount)

    TriggerClientEvent('ox_lib:notify', source, {
        title = '成功', -- 'Success'
        description = string.format('已给予玩家 %s %d个赞助币', targetPlayer.PlayerData.name, amount), -- 'Player %s has been given %d coins'
        type = 'success'
    })

    -- 通知目标玩家
    TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
        title = '获得赞助币', -- 'Coin Reward'
        description = string.format('管理员给予了你 %d个赞助币', amount), -- 'Admin has given you %d coins'
        type = 'success'
    })
end)

-- 添加和查看赞助币余额 - 管理员端 For admin check balance
QBCore.Commands.Add('checkzzb', '查看赞助币余额', {{name = 'id', help = '玩家ID（可选）'}}, false, function(source, args)
    local targetId = tonumber(args[1])
    
    if targetId then
        if not IsPlayerAceAllowed(source, "admin") then
            TriggerClientEvent('ox_lib:notify', source, {
                title = '错误', -- 'Error'
                description = '你没有权限查看其他玩家的余额', -- 'You do not have permission to check other players\' balance'
                type = 'error'
            })
            return
        end
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if not targetPlayer then
            TriggerClientEvent('ox_lib:notify', source, {
                title = '错误', -- 'Error'
                description = '找不到该玩家', -- 'Player not found'
                type = 'error'
            })
            return
        end
        local balance = GetBalance(targetPlayer.PlayerData.citizenid)
        TriggerClientEvent('ox_lib:notify', source, {
            title = '赞助币余额', -- 'Coin Balance'
            description = string.format('玩家 %s 的赞助币余额: %d', targetPlayer.PlayerData.name, balance), -- 'Player %s\' coin balance: %d'
            type = 'info'
        })
    else
        local Player = QBCore.Functions.GetPlayer(source)
        local balance = GetBalance(Player.PlayerData.citizenid)
        TriggerClientEvent('ox_lib:notify', source, {
            title = '赞助币余额', -- 'Coin Balance'
            description = string.format('你的赞助币余额: %d', balance), -- 'Your coin balance: %d'
            type = 'info'
        })
    end
end)