Config = {}

-- Online reward settings
-- 在线奖励给予的货币
Config.OnlineRewardInterval = 1 -- 单位：分钟 The interval of the online reward, in minutes

-- NPC 设置
Config.NPC = {
    model = 'a_m_m_business_01',
    coords = vector4(218.40, -782.00, 30.81, 253.42), -- 请根据需要修改坐标 The store NPC model and coordinates
}

-- 商店物品设置
Config.ShopItems = {
    {
        name = "sultan",
        label = "Sultan跑车",
        price = 10,
        type = "vehicle"
    },
    {
        name = "weapon_pistol",
        label = "手枪",
        price = 5,
        type = "item"
    },
    -- add more items here
    -- 可以继续添加更多商品
}

-- 数据库表名 DataBase table name, this will automatically create the table if it doesn't exist, so better not to touch if u know what u are doing
Config.DatabaseTables = {
    rewards = "sponsor_rewards",
    purchases = "sponsor_purchases"
}