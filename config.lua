Config = {}

-- 在线奖励时长 Online Reward Interval
Config.OnlineRewardInterval = 50 -- minutes

Config.NPC = {
    model = 'a_m_m_business_01',
    coords = vector4(216.10, -806.24, 30.79, 343.02),
}

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
}

-- 数据库表名 这个不用改 自动生成用的 
-- Database table names, these are automatically generated so don't change them if u know what u are doing
Config.DatabaseTables = {
    rewards = "sponsor_rewards",
    purchases = "sponsor_purchases"
}