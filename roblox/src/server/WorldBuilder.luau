-- 旅館のマップをスクリプトで組み立てます（Studio でのモデリング不要）。
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local FLOOR_Y = 1 -- 床の上面の高さ（お客様の足元）
local WALL_H = 10
local ROOM_W = 20
local HALF_W = Config.MaxRooms * ROOM_W / 2
local NORTH_Z = -32 -- 客室の奥の壁
local ROOM_FRONT_Z = -6 -- 客室の入口の壁
local SOUTH_Z = 24 -- 玄関側の壁

local COLORS = {
	Wood = Color3.fromRGB(150, 105, 65),
	DarkWood = Color3.fromRGB(85, 55, 35),
	Tatami = Color3.fromRGB(196, 196, 128),
	Plaster = Color3.fromRGB(240, 232, 215),
	Stone = Color3.fromRGB(135, 135, 128),
	Roof = Color3.fromRGB(55, 60, 70),
	Water = Color3.fromRGB(110, 185, 210),
	Noren = Color3.fromRGB(35, 45, 105),
	Grass = Color3.fromRGB(95, 140, 70),
	Torii = Color3.fromRGB(185, 45, 35),
	Lantern = Color3.fromRGB(220, 70, 50),
	Leaves = Color3.fromRGB(60, 115, 60),
	Futon = Color3.fromRGB(245, 245, 250),
	Locked = Color3.fromRGB(40, 40, 45),
}

local function part(props)
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or COLORS.Wood
	p.Size = props.Size
	if props.Shape then
		p.Shape = props.Shape
	end
	p.CFrame = props.CFrame or CFrame.new(props.Position)
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide ~= nil then
		p.CanCollide = props.CanCollide
	end
	p.Parent = props.Parent
	return p
end

local function label(parent, text, offsetY, width)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 180, 44)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = 90
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.2
	tl.Parent = gui
	gui.Parent = parent
	return tl
end

local function surfaceText(parent, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = textColor or Color3.new(1, 1, 1)
	tl.Parent = gui
	gui.Parent = parent
	return tl
end

function WorldBuilder.Prompt(parent, actionText, objectText, holdDuration)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText or ""
	pp.HoldDuration = holdDuration or 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- x/z 平面上の 2 点を結ぶ壁
local function wall(parent, x1, z1, x2, z2, color)
	local sx = math.max(math.abs(x2 - x1), 1)
	local sz = math.max(math.abs(z2 - z1), 1)
	return part({
		Name = "Wall",
		Size = Vector3.new(sx, WALL_H, sz),
		Position = Vector3.new((x1 + x2) / 2, FLOOR_Y + WALL_H / 2, (z1 + z2) / 2),
		Color = color or COLORS.Plaster,
		Parent = parent,
	})
end

local function tree(parent, x, z, scale)
	part({
		Name = "Trunk",
		Size = Vector3.new(1.5, 8, 1.5) * scale,
		Position = Vector3.new(x, 4 * scale, z),
		Color = COLORS.DarkWood,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9) * scale,
		Position = Vector3.new(x, 9 * scale, z),
		Color = COLORS.Leaves,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
end

local function lantern(parent, position)
	local l = part({
		Name = "Lantern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = position,
		Color = COLORS.Lantern,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 110)
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = l
	return l
end

local function buildRoom(parent, index)
	local x = -HALF_W + ROOM_W * (index - 0.5)
	local depth = ROOM_FRONT_Z - NORTH_Z
	local centerZ = (ROOM_FRONT_Z + NORTH_Z) / 2
	local name = Config.RoomNames[index]

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	part({
		Name = "Tatami",
		Size = Vector3.new(ROOM_W - 2, 0.2, depth - 2),
		Position = Vector3.new(x, FLOOR_Y + 0.1, centerZ),
		Color = COLORS.Tatami,
		Material = Enum.Material.Fabric,
		Parent = model,
	})

	-- 入口側の壁（真ん中に扉 6 スタッド）
	wall(model, x - ROOM_W / 2, ROOM_FRONT_Z, x - 3, ROOM_FRONT_Z)
	wall(model, x + 3, ROOM_FRONT_Z, x + ROOM_W / 2, ROOM_FRONT_Z)
	part({
		Name = "Lintel",
		Size = Vector3.new(6, 3, 1),
		Position = Vector3.new(x, FLOOR_Y + WALL_H - 1.5, ROOM_FRONT_Z),
		Color = COLORS.DarkWood,
		Parent = model,
	})

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(6, 1.6, 0.3),
		Position = Vector3.new(x, FLOOR_Y + WALL_H - 1.5, ROOM_FRONT_Z + 0.7),
		Color = COLORS.Wood,
		Parent = model,
	})
	surfaceText(sign, Enum.NormalId.Back, name, Color3.fromRGB(30, 20, 10))

	local table_ = part({
		Name = "Table",
		Size = Vector3.new(5, 1.2, 3),
		Position = Vector3.new(x, FLOOR_Y + 0.6, -21),
		Color = COLORS.DarkWood,
		Parent = model,
	})

	local futon = part({
		Name = "Futon",
		Size = Vector3.new(5, 0.5, 8),
		Position = Vector3.new(x + 5, FLOOR_Y + 0.45, -26),
		Color = COLORS.Futon,
		Material = Enum.Material.Fabric,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	local lock = part({
		Name = "Lock",
		Size = Vector3.new(ROOM_W - 1, WALL_H, depth - 1),
		Position = Vector3.new(x, FLOOR_Y + WALL_H / 2, centerZ),
		Color = COLORS.Locked,
		Transparency = 0.35,
		Parent = model,
	})
	label(lock, "🔒 工事中", 6.5)

	return {
		Index = index,
		Name = name,
		Model = model,
		Table = table_,
		Futon = futon,
		Lock = lock,
		Corridor = Vector3.new(x, FLOOR_Y, 0),
		Door = Vector3.new(x, FLOOR_Y, ROOM_FRONT_Z),
		Spot = Vector3.new(x, FLOOR_Y, -16),
	}
end

function WorldBuilder.Build()
	local existing = Workspace:FindFirstChild("Ryokan")
	if existing then
		existing:Destroy()
	end
	-- テンプレートの Baseplate / SpawnLocation は旅館と重なるので取り除く
	for _, child in Workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local root = Instance.new("Model")
	root.Name = "Ryokan"
	root.Parent = Workspace

	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	local env = folder("Environment")
	local building = folder("Building")
	local roomsFolder = folder("Rooms")
	local guestsFolder = folder("Guests")

	Lighting.ClockTime = 16.8

	-- 地面・参道・鳥居
	part({
		Name = "Ground",
		Size = Vector3.new(400, 1, 400),
		Position = Vector3.new(0, -0.5, 0),
		Color = COLORS.Grass,
		Material = Enum.Material.Grass,
		Parent = env,
	})
	part({
		Name = "Path",
		Size = Vector3.new(8, 1, 50),
		Position = Vector3.new(0, FLOOR_Y - 0.5, SOUTH_Z + 25),
		Color = COLORS.Stone,
		Material = Enum.Material.Slate,
		Parent = env,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "GatePillar",
			Size = Vector3.new(1.5, 14, 1.5),
			Position = Vector3.new(7 * side, FLOOR_Y + 7, 62),
			Color = COLORS.Torii,
			Parent = env,
		})
		lantern(env, Vector3.new(8 * side, FLOOR_Y + 6, SOUTH_Z + 2))
		tree(env, 25 * side, 50, 1)
		tree(env, 40 * side, 70, 1.2)
	end
	part({
		Name = "GateBeam",
		Size = Vector3.new(20, 1.5, 2),
		Position = Vector3.new(0, FLOOR_Y + 14.5, 62),
		Color = COLORS.Torii,
		Parent = env,
	})
	part({
		Name = "GateBeam2",
		Size = Vector3.new(16, 1, 1.5),
		Position = Vector3.new(0, FLOOR_Y + 11.5, 62),
		Color = COLORS.Torii,
		Parent = env,
	})

	-- 露天風呂（飾り）
	local onsenX = HALF_W + 28
	local water = part({
		Name = "Onsen",
		Size = Vector3.new(24, 0.6, 18),
		Position = Vector3.new(onsenX, 0.3, -5),
		Color = COLORS.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Parent = env,
	})
	local steam = Instance.new("Smoke")
	steam.Color = Color3.new(1, 1, 1)
	steam.Opacity = 0.08
	steam.RiseVelocity = 2
	steam.Size = 6
	steam.Parent = water
	label(water, "♨ 露天風呂", 6)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		part({
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.5,
			Position = Vector3.new(onsenX + math.cos(a) * 13, 0.6, -5 + math.sin(a) * 10),
			Color = COLORS.Stone,
			Material = Enum.Material.Rock,
			Parent = env,
		})
	end

	-- 建物
	part({
		Name = "Floor",
		Size = Vector3.new(HALF_W * 2, 1, SOUTH_Z - NORTH_Z),
		Position = Vector3.new(0, FLOOR_Y - 0.5, (SOUTH_Z + NORTH_Z) / 2),
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
		Parent = building,
	})
	wall(building, -HALF_W, NORTH_Z, HALF_W, NORTH_Z)
	wall(building, -HALF_W, NORTH_Z, -HALF_W, SOUTH_Z)
	wall(building, HALF_W, NORTH_Z, HALF_W, SOUTH_Z)
	wall(building, -HALF_W, SOUTH_Z, -6, SOUTH_Z)
	wall(building, 6, SOUTH_Z, HALF_W, SOUTH_Z)
	for i = 1, Config.MaxRooms - 1 do
		local x = -HALF_W + ROOM_W * i
		wall(building, x, NORTH_Z, x, ROOM_FRONT_Z)
	end

	-- 屋根のひさし（中が見えるよう屋根そのものは付けません）
	local eaveY = FLOOR_Y + WALL_H + 0.5
	local depth = SOUTH_Z - NORTH_Z
	for _, e in {
		{ Vector3.new(HALF_W * 2 + 6, 1, 5), Vector3.new(0, eaveY, NORTH_Z) },
		{ Vector3.new(HALF_W * 2 + 6, 1, 5), Vector3.new(0, eaveY, SOUTH_Z) },
		{ Vector3.new(5, 1, depth), Vector3.new(-HALF_W, eaveY, (SOUTH_Z + NORTH_Z) / 2) },
		{ Vector3.new(5, 1, depth), Vector3.new(HALF_W, eaveY, (SOUTH_Z + NORTH_Z) / 2) },
	} do
		part({ Name = "Eave", Size = e[1], Position = e[2], Color = COLORS.Roof, Material = Enum.Material.Slate, Parent = building })
	end

	local noren = part({
		Name = "Noren",
		Size = Vector3.new(12, 3, 0.2),
		Position = Vector3.new(0, FLOOR_Y + WALL_H - 1.5, SOUTH_Z + 0.7),
		Color = COLORS.Noren,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = building,
	})
	surfaceText(noren, Enum.NormalId.Back, "旅 館")

	-- フロント
	local desk = part({
		Name = "FrontDesk",
		Size = Vector3.new(12, 3.5, 2),
		Position = Vector3.new(0, FLOOR_Y + 1.75, 10),
		Color = COLORS.DarkWood,
		Parent = building,
	})
	label(desk, "🛎️ フロント", 4)

	-- 厨房と給湯室
	local kitchen = part({
		Name = "Kitchen",
		Size = Vector3.new(10, 3.5, 3),
		Position = Vector3.new(-HALF_W + 10, FLOOR_Y + 1.75, 12),
		Color = Color3.fromRGB(200, 200, 205),
		Material = Enum.Material.Metal,
		Parent = building,
	})
	label(kitchen, "🍱 厨房", 4)

	local teaStation = part({
		Name = "TeaStation",
		Size = Vector3.new(8, 3.5, 3),
		Position = Vector3.new(HALF_W - 10, FLOOR_Y + 1.75, 12),
		Color = COLORS.Wood,
		Parent = building,
	})
	label(teaStation, "🍵 給湯室", 4)

	-- 増築の掲示板（玄関の内側の壁）
	local board = part({
		Name = "UpgradeBoard",
		Size = Vector3.new(10, 5, 0.5),
		Position = Vector3.new(25, FLOOR_Y + 4.5, SOUTH_Z - 0.75),
		Color = COLORS.DarkWood,
		Parent = building,
	})
	local boardText = surfaceText(board, Enum.NormalId.Front, "🔨 増築")

	-- プレイヤーのスポーン（フロントの内側）
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StaffSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.Position = Vector3.new(0, FLOOR_Y + 0.1, 4)
	spawn.Color = COLORS.Wood
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = building

	local rooms = {}
	for i = 1, Config.MaxRooms do
		rooms[i] = buildRoom(roomsFolder, i)
	end

	local queueSpots = {}
	for k = 1, Config.MaxQueue do
		queueSpots[k] = Vector3.new(0, FLOOR_Y, 13 + (k - 1) * 4)
	end

	return {
		Root = root,
		GuestsFolder = guestsFolder,
		Desk = desk,
		Kitchen = kitchen,
		TeaStation = teaStation,
		UpgradeBoard = board,
		UpgradeText = boardText,
		Rooms = rooms,
		QueueSpots = queueSpots,
		-- お客様の通り道
		GateSpawn = Vector3.new(0, FLOOR_Y, 72),
		DeskSide = Vector3.new(9, FLOOR_Y, 13),
		CorridorEntry = Vector3.new(9, FLOOR_Y, 0),
		LobbyExit = Vector3.new(9, FLOOR_Y, 18),
		EntranceOut = Vector3.new(0, FLOOR_Y, SOUTH_Z + 6),
	}
end

return WorldBuilder
