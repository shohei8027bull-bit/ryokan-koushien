-- 所持金と客室数の保存・読み込み（DataStore）。
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataManager = {}

local AUTOSAVE_INTERVAL = 120
local MONEY_STAT = "所持金"

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("RyokanData_v1")
	end)
	if ok then
		store = result
	else
		warn("[DataManager] DataStore が使えません。データは保存されません:", result)
	end
end

local profiles = {} -- [Player] = { Money, Rooms, CanSave }
local loadedCallbacks = {}

local function keyFor(player)
	return "player_" .. player.UserId
end

local function load(player)
	local data
	local fetched = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(store.GetAsync, store, keyFor(player))
			if ok then
				data = result
				fetched = true
				break
			end
			warn(("[DataManager] 読み込み失敗 (%d/3): %s"):format(attempt, tostring(result)))
			task.wait(2)
		end
	end
	if not player.Parent then
		return
	end
	data = data or {}

	-- 読み込みに失敗したときは、保存済みデータを初期値で上書きしないよう保存を止める
	local profile = {
		Money = data.Money or Config.StartingMoney,
		Rooms = data.Rooms or Config.StartingRooms,
		CanSave = fetched,
	}
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = MONEY_STAT
	money.Value = profile.Money
	money.Parent = leaderstats
	leaderstats.Parent = player
	player:SetAttribute("Rooms", profile.Rooms)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function save(player)
	local profile = profiles[player]
	if not (store and profile and profile.CanSave) then
		return
	end
	local ok, err = pcall(store.SetAsync, store, keyFor(player), {
		Money = profile.Money,
		Rooms = profile.Rooms,
	})
	if not ok then
		warn("[DataManager] 保存失敗:", err)
	end
end

local function syncMoney(player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(MONEY_STAT)
	if stat then
		stat.Value = profile.Money
	end
end

function DataManager.OnLoaded(callback)
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function DataManager.GetMoney(player)
	local profile = profiles[player]
	return profile and profile.Money or 0
end

function DataManager.AddMoney(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Money += amount
	syncMoney(player, profile)
end

function DataManager.SpendMoney(player, amount)
	local profile = profiles[player]
	if not profile or profile.Money < amount then
		return false
	end
	profile.Money -= amount
	syncMoney(player, profile)
	return true
end

function DataManager.SetRooms(player, rooms)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Rooms = rooms
	player:SetAttribute("Rooms", rooms)
end

function DataManager.Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataManager
