-- ゲーム全体の設定。数値をいじるだけでバランス調整できます。
local Config = {}

-- プレイヤー
Config.StartingMoney = 0
Config.StartingRooms = 2

-- 客室（並び順に増築されます）
Config.RoomNames = { "松の間", "竹の間", "梅の間", "桜の間", "藤の間", "菊の間" }
Config.MaxRooms = #Config.RoomNames
Config.RoomPrices = { [3] = 300, [4] = 600, [5] = 1200, [6] = 2000 } -- [何部屋目] = 増築費用

-- お客様
Config.RoomRate = 100 -- 基本の宿泊料（満足度で 0.5〜1.5 倍）
Config.GuestSpawnInterval = { Min = 6, Max = 16 } -- 評判★5で Min 秒、★1で Max 秒ごとに来店
Config.GuestWalkSpeed = 12
Config.MaxQueue = 4
Config.QueuePatience = 90 -- フロントで待てる秒数
Config.RequestPatience = 45 -- 1つのお願いを待てる秒数
Config.RequestsPerGuest = { Min = 2, Max = 3 }
Config.RelaxTime = { Min = 3, Max = 7 } -- お願いとお願いの間の秒数

-- 満足度・評判
Config.StartingSatisfaction = 60
Config.ServeSatisfaction = 15
Config.FailSatisfaction = 25
Config.StartingReputation = 3

-- 持ち運ぶアイテム
Config.Items = {
	Tea = { Label = "お茶", Station = "給湯室" },
	Meal = { Label = "お料理", Station = "厨房" },
}

-- お客様のお願い（RequestOrder の順番で発生します）
Config.RequestOrder = { "Tea", "Meal", "Futon" }
Config.Requests = {
	Tea = { Label = "お茶", Icon = "🍵", Action = "お茶を出す", Tip = 20, Item = "Tea" },
	Meal = { Label = "お料理", Icon = "🍱", Action = "お料理を出す", Tip = 40, Item = "Meal" },
	Futon = { Label = "お布団", Icon = "🛏️", Action = "布団を敷く", Tip = 25, HoldDuration = 2 },
}

return Config
