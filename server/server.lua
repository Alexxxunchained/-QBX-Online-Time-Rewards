local QBCore = exports['qb-core']:GetCoreObject()

-- 初始化数据库表 Initialize database table
local function InitializeDatabase() 
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sponsor_balance (
            citizenid VARCHAR(50) PRIMARY KEY,
            balance INT DEFAULT 0
        )
    ]])

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

-- 记录赞助币奖励 Record reward
local function RecordReward(identifier, amount)
    MySQL.insert('INSERT INTO '..Config.DatabaseTables.rewards..' (identifier, amount) VALUES (?, ?)',
        {identifier, amount})
end

-- 记录购买历史 Record purchase
local function RecordPurchase(identifier, itemName, itemType, price)
    MySQL.insert('INSERT INTO '..Config.DatabaseTables.purchases..' (identifier, item_name, item_type, price) VALUES (?, ?, ?, ?)',
        {identifier, itemName, itemType, price})
end

-- 添加获取余额函数 Get balance
local function GetBalance(citizenid)
    local result = MySQL.scalar.await('SELECT balance FROM sponsor_balance WHERE citizenid = ?', {citizenid})
    return result or 0
end

-- 添加更新余额函数 Update balance
local function UpdateBalance(citizenid, amount)
    MySQL.query.await([[
        INSERT INTO sponsor_balance (citizenid, balance) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE balance = balance + ?
    ]], {citizenid, amount, amount})
end

-- 购买物品事件 Purchase item event
RegisterNetEvent('sponsor:purchaseItem', function(itemName, itemType, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- 检查玩家是否有足够的赞助币 Check if the player has enough sponsor coins
    local balance = GetBalance(Player.PlayerData.citizenid)
    if balance < price then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '错误',
            description = '赞助币不足！', -- EB version: Coins are insufficient!
            type = 'error'
        })
        return
    end

    -- 扣除赞助币 Deduct sponsor coins
    UpdateBalance(Player.PlayerData.citizenid, -price)

    -- 如果是车辆的话 if the item is a vehicle
    if itemType == 'vehicle' then
        local plate = GeneratePlate()
        -- 来自givecar的snippet below code is I quote(Stolen) from givecar script
        local vehicleData = {
            model = itemName,
            plate = plate,
            garage = "pillboxgarage", -- garage name, according to the different garage scripts maybe you need to make some changes but if u are using JG-Advancedgarage then u can igored this
            state = 1,
            mods = '{}'
        }
        
        -- 数据库插入车辆数据 Insert vehicle data into database
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
                        title = '购买成功',
                        description = '车辆已存入车库', -- Vehicle has been stored in the garage
                        type = 'success'
                    })
                else
                    -- 如果插入失败 退还赞助币 If the insertion fails, refund the coins
                    UpdateBalance(Player.PlayerData.citizenid, price)
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '错误',
                        description = '购买失败，赞助币已退还', -- Purchase failed, coins have been refunded
                        type = 'error'
                    })
                end
            end)
    else
        exports.ox_inventory:AddItem(src, itemName, 1)
        TriggerClientEvent('ox_lib:notify', src, {
            title = '购买成功', -- Purchase successful
            description = '成功购买 ' .. itemName, -- Successfully purchased itemName EN version: Successfully purchased 
            type = 'success'
        })
    end

    -- 记录购买 Record purchase
    RecordPurchase(Player.PlayerData.citizenid, itemName, itemType, price)
end)

-- 获取玩家购买历史 Get player purchase history
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

-- 获取所有历史记录（管理员端） Get all history (admin side)
lib.callback.register('sponsor:getAllHistory', function(source)
    -- 检查是否有admin权限 Check if the player has admin permissions
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

-- 在线时长则奖励玩家赞助币余额 同时更新且记录赞助币的数据库活动 Online time rewards player coins and update and record coins database activity I know this is a bad code but I'm too lazy to fix it if this working juat fine
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
                    title = '在线奖励', -- Online reward
                    description = '你获得了1个赞助币！', -- You have been rewarded 1 coin!
                    type = 'success'
                })
            end
        end
    end
end)

-- 生成车牌号 这里你可以自己改一下你想要的车牌号格式 RandomStr(3)是指3个字符 也就是字母  QBCore.Shared.RandomInt(3)是指3个数字
-- For some reasons, some of people may want to use their own plate format, so I leave this function for you to modify
function GeneratePlate()
    local plate = QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(3)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    end
    return plate
end

-- Initialize database and print some shit, u can delete print if u want but dont delete InitializeDatabase() cuz this is a must
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        InitializeDatabase()
        print('^2[MySword:Coins]^5 Thx for using my script')
    end
end)

-- dont ask me why this is here and did nothing, cuz Im using template LOL
AddEventHandler('onResourceStop', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then
    return
  end

end)

-- 余额回调 Balance callback
lib.callback.register('sponsor:getBalance', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return GetBalance(Player.PlayerData.citizenid)
end)

-- 管理员指令 Admin command
QBCore.Commands.Add('givezzb', 'Give Coins', {{name = 'id', help = 'ID'}, {name = 'amount', help = '数量'}}, true, function(source, args)
    -- 检查管理员权限
    if not IsPlayerAceAllowed(source, "admin") then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- Error
            description = '你没有权限使用此命令', -- You do not have permission to use this command
            type = 'error'
        })
        return
    end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])

    -- 检查参数是否有效
    if not targetId or not amount then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- Error
            description = '参数错误', -- Parameter error
            type = 'error'
        })
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '错误', -- Error
            description = '找不到该玩家', -- Player not found
            type = 'error'
        })
        return
    end

    -- 更新赞助币余额 Update sponsor coin balance
    UpdateBalance(targetPlayer.PlayerData.citizenid, amount)
    
    -- 记录奖励 Record reward
    RecordReward(targetPlayer.PlayerData.citizenid, amount)

    -- 通知管理员 Notify admin
    TriggerClientEvent('ox_lib:notify', source, {
        title = '成功', -- Success
        description = string.format('已给予玩家 %s %d个赞助币', targetPlayer.PlayerData.name, amount), -- Successfully given player %s %d coins
        type = 'success'
    })

    -- 通知 Notify target player
    TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
        title = '获得赞助币', -- Received coins
        description = string.format('管理员给予了你 %d个赞助币', amount), -- Admin gave you %d coins
        type = 'success'
    })
end)

-- 添加和查看赞助币余额 - 管理员端 Add and check sponsor coin balance - admin side
QBCore.Commands.Add('checkzzb', '查看赞助币余额', {{name = 'id', help = 'ID（optional）'}}, false, function(source, args)
    local targetId = tonumber(args[1])
    
    if targetId then
        -- 如果要查看某个具体的玩家的赞助币余额的话就先查看管理员ACE权限 If u want to check a specific player's sponsor coin balance, first check admin ACE permissions
        if not IsPlayerAceAllowed(source, "admin") then
            TriggerClientEvent('ox_lib:notify', source, {
                title = '错误', -- Error
                description = '你没有权限查看其他玩家的余额', -- You do not have permission to check other players' balances
                type = 'error'
            })
            return
        end
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if not targetPlayer then
            TriggerClientEvent('ox_lib:notify', source, {
                title = '错误', -- Error
                description = '找不到该玩家', -- Player not found
                type = 'error'
            })
            return
        end
        local balance = GetBalance(targetPlayer.PlayerData.citizenid)
        TriggerClientEvent('ox_lib:notify', source, {
            title = '赞助币余额', -- Coin balance
            description = string.format('玩家 %s 的赞助币余额: %d', targetPlayer.PlayerData.name, balance), -- Player %s's coin balance: %d
            type = 'info'
        })
    else
        local Player = QBCore.Functions.GetPlayer(source)
        local balance = GetBalance(Player.PlayerData.citizenid)
        TriggerClientEvent('ox_lib:notify', source, {
            title = '赞助币余额', -- Sponsor coin balance
            description = string.format('你的赞助币余额: %d', balance), -- Your sponsor coin balance: %d
            type = 'info'
        })
    end
end)

-- OX LIB IS SOOOOO GOOD TO USE