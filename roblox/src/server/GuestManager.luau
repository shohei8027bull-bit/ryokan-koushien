-- お客様の来店・チェックイン・お世話・チェックアウトを管理します。
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local GuestManager = {}

local rng = Random.new()
local world, data, notify
local queue = {} -- フロントに並んでいるお客様（先頭がチェックイン対象）
local unlockedRooms = 0

local KIMONO_COLORS = {
	Color3.fromRGB(70, 90, 160),
	Color3.fromRGB(170, 70, 90),
	Color3.fromRGB(80, 140, 110),
	Color3.fromRGB(150, 110, 170),
	Color3.fromRGB(200, 140, 60),
}
local HAIR_COLORS = {
	Color3.fromRGB(30, 25, 20),
	Color3.fromRGB(80, 55, 35),
	Color3.fromRGB(170, 170, 170),
}

local function stars(n)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

---------------------------------------------------------------------------
-- 評判
---------------------------------------------------------------------------

local function getReputation()
	return ReplicatedStorage:GetAttribute("Reputation") or Config.StartingReputation
end

local function addRating(rating)
	local rep = getReputation() * 0.75 + rating * 0.25
	ReplicatedStorage:SetAttribute("Reputation", math.round(rep * 100) / 100)
end

---------------------------------------------------------------------------
-- お客様の見た目
---------------------------------------------------------------------------

local function buildGuestModel(feet)
	local model = Instance.new("Model")
	model.Name = "Guest"
	local kimono = KIMONO_COLORS[rng:NextInteger(1, #KIMONO_COLORS)]

	local function gp(name, size, offsetY, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.CFrame = CFrame.new(feet + Vector3.new(0, offsetY, 0))
		p.Parent = model
		return p
	end

	gp("Legs", Vector3.new(1.6, 1.8, 1), 0.9, kimono:Lerp(Color3.new(0, 0, 0), 0.3))
	gp("Body", Vector3.new(2, 2.2, 1.2), 2.9, kimono)
	gp("Obi", Vector3.new(2.05, 0.5, 1.25), 2.4, Color3.fromRGB(230, 200, 90))
	local head = gp("Head", Vector3.new(1.6, 1.6, 1.6), 4.8, Color3.fromRGB(255, 220, 185), Enum.PartType.Ball)
	gp("Hair", Vector3.new(1.7, 0.6, 1.7), 5.5, HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)])

	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- 頭の上の吹き出し
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(170, 64)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 0, 40)
	text.BackgroundColor3 = Color3.new(1, 1, 1)
	text.BackgroundTransparency = 0.1
	text.TextColor3 = Color3.fromRGB(40, 30, 20)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = ""
	Instance.new("UICorner").Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = text
	text.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.new(0.1, 0, 0, 46)
	bar.Size = UDim2.new(0.8, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	bar.Visible = false
	Instance.new("UICorner").Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	Instance.new("UICorner").Parent = fill
	fill.Parent = bar
	bar.Parent = gui

	gui.Parent = head
	model.WorldPivot = CFrame.new(feet)
	model.Parent = world.GuestsFolder
	return model, text, bar, fill
end

local function setStatus(guest, text)
	guest.Text.Text = text
end

local function setBar(guest, ratio)
	if ratio == nil then
		guest.Bar.Visible = false
		return
	end
	ratio = math.clamp(ratio, 0, 1)
	guest.Bar.Visible = true
	guest.Fill.Size = UDim2.fromScale(ratio, 1)
	guest.Fill.BackgroundColor3 = Color3.fromRGB(220, 70, 60):Lerp(Color3.fromRGB(90, 200, 90), ratio)
end

---------------------------------------------------------------------------
-- 移動
---------------------------------------------------------------------------

local function alive(guest)
	return guest.Model.Parent ~= nil
end

local function stepTowards(guest, target, token)
	local model = guest.Model
	while true do
		if guest.WalkToken ~= token or not alive(guest) then
			return false
		end
		local current = model:GetPivot()
		local delta = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
		local dist = delta.Magnitude
		local step = Config.GuestWalkSpeed * RunService.Heartbeat:Wait()
		if guest.WalkToken ~= token or not alive(guest) then
			return false
		end
		local dir = if dist > 1e-3 then delta.Unit else current.LookVector
		local pos = if dist <= step then target else current.Position + dir * step
		pos = Vector3.new(pos.X, target.Y, pos.Z)
		model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)))
		if dist <= step then
			return true
		end
	end
end

-- 新しく歩き出すと、それまでの移動は打ち切られます
local function walkPath(guest, points)
	guest.WalkToken += 1
	local token = guest.WalkToken
	for _, point in points do
		if not stepTowards(guest, point, token) then
			return false
		end
	end
	return true
end

local function faceTowards(guest, position)
	local pivot = guest.Model:GetPivot()
	local look = Vector3.new(position.X, pivot.Y, position.Z)
	if (look - pivot.Position).Magnitude > 1e-3 then
		guest.Model:PivotTo(CFrame.lookAt(pivot.Position, look))
	end
end

local function leave(guest)
	guest.State = "Leaving"
	setBar(guest, nil)
	local points = {}
	if guest.Room then
		table.insert(points, guest.Room.Door)
		table.insert(points, guest.Room.Corridor)
		table.insert(points, world.CorridorEntry)
		table.insert(points, world.LobbyExit)
	end
	table.insert(points, world.EntranceOut)
	table.insert(points, world.GateSpawn)
	walkPath(guest, points)
	guest.Model:Destroy()
end

---------------------------------------------------------------------------
-- 客室
---------------------------------------------------------------------------

local function findFreeRoom()
	for i = 1, unlockedRooms do
		local room = world.Rooms[i]
		if not room.Guest then
			return room
		end
	end
	return nil
end

local function refreshRoomPrompt(room)
	local guest = room.Guest
	local request = guest and guest.Request
	if request and not request.Done then
		local def = Config.Requests[request.Kind]
		room.Prompt.ActionText = def.Action
		room.Prompt.ObjectText = room.Name
		room.Prompt.HoldDuration = def.HoldDuration or 0
		room.Prompt.Enabled = true
	else
		room.Prompt.Enabled = false
	end
end

function GuestManager.UnlockRooms(count)
	count = math.clamp(count, 0, Config.MaxRooms)
	for i = unlockedRooms + 1, count do
		local room = world.Rooms[i]
		if room.Lock then
			room.Lock:Destroy()
			room.Lock = nil
		end
	end
	unlockedRooms = math.max(unlockedRooms, count)
end

function GuestManager.GetUnlockedRooms()
	return unlockedRooms
end

---------------------------------------------------------------------------
-- 持ち物
---------------------------------------------------------------------------

local function setCarry(player, item)
	player:SetAttribute("Carrying", item)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("CarriedItem")
	if old then
		old:Destroy()
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (item and hrp) then
		return
	end
	local p = Instance.new("Part")
	p.Name = "CarriedItem"
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	if item == "Tea" then
		p.Size = Vector3.new(0.8, 1, 0.8)
		p.Color = Color3.fromRGB(110, 150, 80)
	else
		p.Size = Vector3.new(2, 0.4, 1.4)
		p.Color = Color3.fromRGB(160, 40, 40)
	end
	p.CFrame = hrp.CFrame * CFrame.new(0, 0.3, -1.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = p
	weld.Parent = p
	p.Parent = character
end

---------------------------------------------------------------------------
-- お客様の流れ
---------------------------------------------------------------------------

local function checkout(guest)
	local room = guest.Room
	local rating = math.clamp(math.ceil(guest.Satisfaction / 20), 1, 5)
	local pay = math.floor(Config.RoomRate * (0.5 + guest.Satisfaction / 100))

	local payee = guest.Host
	if not (payee and payee.Parent) then
		payee = Players:GetPlayers()[1]
	end
	if payee then
		data.AddMoney(payee, pay)
	end
	addRating(rating)

	setStatus(guest, stars(rating))
	notify(nil, ("%sのお客様がチェックアウト %s  宿泊料 ¥%d"):format(room.Name, stars(rating), pay))

	room.Guest = nil
	room.Futon.Transparency = 1
	refreshRoomPrompt(room)
	leave(guest)
end

local function pickRequests()
	local count = rng:NextInteger(Config.RequestsPerGuest.Min, Config.RequestsPerGuest.Max)
	local pool = table.clone(Config.RequestOrder)
	while #pool > count do
		table.remove(pool, rng:NextInteger(1, #pool))
	end
	return pool -- 順番は RequestOrder のまま
end

local function stay(guest)
	local room = guest.Room
	guest.State = "Staying"
	for _, kind in pickRequests() do
		setStatus(guest, "😌 くつろぎ中…")
		task.wait(rng:NextNumber(Config.RelaxTime.Min, Config.RelaxTime.Max))
		if not alive(guest) then
			return
		end

		local def = Config.Requests[kind]
		local request = { Kind = kind, Deadline = os.clock() + Config.RequestPatience, Done = false }
		guest.Request = request
		setStatus(guest, ("%s %sをお願いします"):format(def.Icon, def.Label))
		refreshRoomPrompt(room)

		while not request.Done and os.clock() < request.Deadline do
			setBar(guest, (request.Deadline - os.clock()) / Config.RequestPatience)
			task.wait(0.2)
		end
		setBar(guest, nil)

		if not request.Done then
			guest.Satisfaction = math.max(0, guest.Satisfaction - Config.FailSatisfaction)
			notify(nil, ("%sのお客様が%sを待ちきれませんでした…"):format(room.Name, def.Label))
		end
		guest.Request = nil
		refreshRoomPrompt(room)
	end
	setStatus(guest, "😊 ありがとう！")
	task.wait(2)
	checkout(guest)
end

local function serve(player, room)
	local guest = room.Guest
	local request = guest and guest.Request
	if not request or request.Done then
		return
	end
	local def = Config.Requests[request.Kind]

	if def.Item then
		if player:GetAttribute("Carrying") ~= def.Item then
			local item = Config.Items[def.Item]
			notify(player, ("%sを%sで受け取ってきてください"):format(item.Label, item.Station))
			return
		end
		setCarry(player, nil)
	end

	request.Done = true
	local remaining = math.clamp((request.Deadline - os.clock()) / Config.RequestPatience, 0, 1)
	local tip = def.Tip + math.floor(def.Tip * remaining) -- 早いほどチップが増える
	guest.Satisfaction = math.min(100, guest.Satisfaction + Config.ServeSatisfaction)
	data.AddMoney(player, tip)
	if request.Kind == "Futon" then
		room.Futon.Transparency = 0
	end
	setStatus(guest, "😊 ありがとう！")
	notify(player, ("%sをお出ししました！ チップ ¥%d"):format(def.Label, tip))
	refreshRoomPrompt(room)
end

local function relayoutQueue()
	for index, guest in queue do
		if guest.QueueIndex ~= index then
			guest.QueueIndex = index
			guest.Arrived = false
			task.spawn(function()
				if walkPath(guest, { world.QueueSpots[index] }) then
					guest.Arrived = true
					faceTowards(guest, world.Desk.Position)
				end
			end)
		end
	end
end

local function removeFromQueue(guest)
	local index = table.find(queue, guest)
	if index then
		table.remove(queue, index)
		relayoutQueue()
	end
end

local function checkIn(player)
	local guest = queue[1]
	if not (guest and guest.Arrived) then
		return
	end
	local room = findFreeRoom()
	if not room then
		notify(player, "満室です。チェックアウトを待つか、客室を増築しましょう")
		return
	end

	removeFromQueue(guest)
	guest.State = "ToRoom"
	guest.Room = room
	guest.Host = player
	room.Guest = guest
	setStatus(guest, ("%sへご案内"):format(room.Name))
	notify(player, ("%sへご案内しました"):format(room.Name))

	task.spawn(function()
		if walkPath(guest, { world.DeskSide, world.CorridorEntry, room.Corridor, room.Door, room.Spot }) then
			faceTowards(guest, room.Table.Position)
			stay(guest)
		end
	end)
end

local function spawnGuest()
	local model, text, bar, fill = buildGuestModel(world.GateSpawn)
	local guest = {
		Model = model,
		Text = text,
		Bar = bar,
		Fill = fill,
		State = "Queue",
		WalkToken = 0,
		Satisfaction = Config.StartingSatisfaction,
		QueueDeadline = os.clock() + Config.QueuePatience,
	}
	setStatus(guest, "🧳 チェックイン待ち")
	table.insert(queue, guest)
	relayoutQueue()
end

local function updateQueue()
	-- 待ちくたびれたお客様は帰ってしまう
	for i = #queue, 1, -1 do
		local guest = queue[i]
		if os.clock() > guest.QueueDeadline then
			removeFromQueue(guest)
			setStatus(guest, "😠 もう帰ります！")
			addRating(1)
			notify(nil, "お客様が待ちくたびれて帰ってしまいました…")
			task.spawn(leave, guest)
		elseif guest.Arrived then
			setBar(guest, (guest.QueueDeadline - os.clock()) / Config.QueuePatience)
		end
	end

	local front = queue[1]
	local prompt = world.DeskPrompt
	if front and front.Arrived then
		local room = findFreeRoom()
		prompt.ObjectText = if room then ("空室: %s"):format(room.Name) else "満室"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

---------------------------------------------------------------------------
-- 起動
---------------------------------------------------------------------------

function GuestManager.Start(worldRefs, dataManager, notifyFn)
	world = worldRefs
	data = dataManager
	notify = notifyFn

	if ReplicatedStorage:GetAttribute("Reputation") == nil then
		ReplicatedStorage:SetAttribute("Reputation", Config.StartingReputation)
	end

	world.DeskPrompt = WorldBuilder.Prompt(world.Desk, "チェックイン", "")
	world.DeskPrompt.Enabled = false
	world.DeskPrompt.Triggered:Connect(checkIn)

	for _, room in world.Rooms do
		room.Prompt = WorldBuilder.Prompt(room.Table, "", room.Name)
		room.Prompt.Enabled = false
		room.Prompt.Triggered:Connect(function(player)
			serve(player, room)
		end)
	end

	WorldBuilder.Prompt(world.Kitchen, "お料理を受け取る", "厨房", 1).Triggered:Connect(function(player)
		setCarry(player, "Meal")
		notify(player, "🍱 お料理を持ちました。お客様の部屋へ運びましょう")
	end)
	WorldBuilder.Prompt(world.TeaStation, "お茶を淹れる", "給湯室", 1).Triggered:Connect(function(player)
		setCarry(player, "Tea")
		notify(player, "🍵 お茶を持ちました。お客様の部屋へ運びましょう")
	end)

	local function onCharacter(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Carrying", nil)
		end)
	end
	Players.PlayerAdded:Connect(onCharacter)
	for _, player in Players:GetPlayers() do
		onCharacter(player)
	end

	task.spawn(function()
		while true do
			updateQueue()
			task.wait(0.25)
		end
	end)

	task.spawn(function()
		while true do
			-- 評判が高いほどお客様がよく来る
			local t = (getReputation() - 1) / 4
			local interval = Config.GuestSpawnInterval.Max
				- (Config.GuestSpawnInterval.Max - Config.GuestSpawnInterval.Min) * t
			task.wait(interval)
			if #Players:GetPlayers() > 0 and #queue < Config.MaxQueue then
				spawnGuest()
			end
		end
	end)
end

return GuestManager
