local QBCore = exports['qb-core']:GetCoreObject()

-- PlayerData初始化
local PlayerData = QBCore.Functions.GetPlayerData()

-- 更新PlayerData
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData = QBCore.Functions.GetPlayerData()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end

end)

-- cuz Im using template so no worry thing above this line, they are just for reference
CreateThread(function()
    lib.requestModel(Config.NPC.model)
    local ped = CreatePed(4, Config.NPC.model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1.0, Config.NPC.coords.w, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'sponsor_shop',
            icon = 'fas fa-shop',
            label = '赞助币商店',  -- store lable
            onSelect = function()
                OpenSponsorShop()
            end
        },
        {
            name = 'purchase_history',
            icon = 'fas fa-history',
            label = '购买历史',  -- purchase history lable
            onSelect = function()
                ShowPurchaseHistory()
            end
        },
        {
            name = 'admin_history',
            icon = 'fas fa-list',
            label = '全部历史记录',  -- if u are admin, u can see all history lable
            onSelect = function()
                ShowAdminHistory()
            end,
            canInteract = function()
                return lib.callback.await('sponsor:checkAdmin', false)
            end
        }
    })
end)

-- 赞助币商店 store function
function OpenSponsorShop()
    -- 获取玩家赞助币余额 -- get player coin balance
    lib.callback('sponsor:getBalance', false, function(balance)
        local options = {
            {
                title = '当前余额',  -- current balance lable
                description = string.format('你现在拥有 %d 个赞助币', balance),  -- current balance description EN version: You currently have %d coins
                icon = 'fas fa-coins',
                disabled = true
            }
        }
        
        for _, item in ipairs(Config.ShopItems) do
            table.insert(options, {
                title = item.label,  -- item lable
                description = string.format('价格: %d 赞助币', item.price),  -- item price description EN version: Price: %d coins
                icon = item.type == 'vehicle' and 'fas fa-car' or 'fas fa-box',  -- item icon, if item is vehicle, use car icon, else use box icon
                onSelect = function()
                    TriggerServerEvent('sponsor:purchaseItem', item.name, item.type, item.price)
                end,
                disabled = balance < item.price
            })
        end
        
        lib.registerContext({
            id = 'sponsor_shop',
            title = '赞助币商店',  -- store lable EN version: Coin Store
            options = options
        })

        lib.showContext('sponsor_shop')
    end)
end

-- 购买历史 purchase history function
function ShowPurchaseHistory()
    lib.callback('sponsor:getPurchaseHistory', false, function(history)
        if not history then return end
        
        local options = {}
        for _, purchase in ipairs(history) do
            local itemLabel = purchase.item_name -- default value
            local itemType = 'item' -- default type
            for _, configItem in ipairs(Config.ShopItems) do
                if configItem.name == purchase.item_name then
                    itemLabel = configItem.label
                    itemType = configItem.type
                    break
                end
            end
            
            table.insert(options, {
                title = itemLabel,  -- item lable
                description = '购买时间: '..purchase.formatted_time,  -- purchase time description EN version: Purchase time: ........
                icon = itemType == 'vehicle' and 'fas fa-car' or 'fas fa-box'  -- item icon, if item is vehicle, use car icon, else use box icon
            })
        end
        
        lib.registerContext({
            id = 'purchase_history',
            title = '购买历史',  -- purchase history lable EN version: Purchase History
            options = options
        })

        lib.showContext('purchase_history')
    end)
end

-- 管理员历史记录 admin history function
function ShowAdminHistory()
    lib.callback('sponsor:getAllHistory', false, function(history)
        if not history then return end
        
        local options = {}
        for _, reward in ipairs(history.rewards) do
            table.insert(options, {
                title = '赞助币奖励',  -- reward lable EN version: Reward Claimed History
                description = string.format('玩家: %s, 数量: %d, 时间: %s',  -- reward description EN version: Player: %s, Amount: %d, Time: %s
                    reward.identifier, reward.amount, reward.formatted_time),
                icon = 'fas fa-coins'
            })
        end
        
        for _, purchase in ipairs(history.purchases) do
            local itemLabel = purchase.item_name
            local itemType = 'item'
            for _, configItem in ipairs(Config.ShopItems) do
                if configItem.name == purchase.item_name then
                    itemLabel = configItem.label
                    itemType = configItem.type
                    break
                end
            end

            table.insert(options, {
                title = '物品购买',  -- item purchase lable EN version: Item Purchased
                description = string.format('玩家: %s, 物品: %s, 价格: %d, 时间: %s',  -- item purchase description EN version: Player: %s, Item: %s, Price: %d, Time: %s
                    purchase.identifier, itemLabel, purchase.price, purchase.formatted_time),
                icon = itemType == 'vehicle' and 'fas fa-car' or 'fas fa-box'
            })
        end
        
        lib.registerContext({
            id = 'admin_history',
            title = '全部历史记录',  -- all history lable EN version: All History
            options = options
        })

        lib.showContext('admin_history')
    end)
end