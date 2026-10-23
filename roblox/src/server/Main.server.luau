-- サーバーの入口。マップを作り、データとお客様の管理を始めます。
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local GuestManager = require(script.Parent:WaitForChild("GuestManager"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

-- target が nil なら全員に通知
local function notify(target, text)
	if target then
		notifyEvent:FireClient(target, text)
	else
		notifyEvent:FireAllClients(text)
	end
end

local world = WorldBuilder.Build()
GuestManager.Start(world, DataManager, notify)
GuestManager.UnlockRooms(Config.StartingRooms)

-- 増築：サーバー内で一番大きい旅館の客室数を使います
local upgradePrompt = WorldBuilder.Prompt(world.UpgradeBoard, "客室を増築", "")

local function refreshUpgrade()
	local rooms = GuestManager.GetUnlockedRooms()
	if rooms >= Config.MaxRooms then
		world.UpgradeText.Text = "🏯 全室オープン！"
		upgradePrompt.Enabled = false
		return
	end
	local price = Config.RoomPrices[rooms + 1]
	world.UpgradeText.Text = ("🔨 増築\n%s  ¥%d"):format(Config.RoomNames[rooms + 1], price)
	upgradePrompt.ObjectText = ("%s ¥%d"):format(Config.RoomNames[rooms + 1], price)
	upgradePrompt.Enabled = true
end

upgradePrompt.Triggered:Connect(function(player)
	local rooms = GuestManager.GetUnlockedRooms()
	if rooms >= Config.MaxRooms then
		return
	end
	local price = Config.RoomPrices[rooms + 1]
	if not DataManager.SpendMoney(player, price) then
		notify(player, ("お金が足りません（¥%d 必要）"):format(price))
		return
	end
	DataManager.SetRooms(player, rooms + 1)
	GuestManager.UnlockRooms(rooms + 1)
	refreshUpgrade()
	notify(nil, ("🎉 %sさんが「%s」を増築しました！"):format(player.DisplayName, Config.RoomNames[rooms + 1]))
end)

DataManager.OnLoaded(function(player, profile)
	GuestManager.UnlockRooms(profile.Rooms)
	refreshUpgrade()
	notify(player, "ようこそ！フロントでお客様をチェックインしましょう")
end)

refreshUpgrade()
DataManager.Start()
