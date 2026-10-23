-- 画面左上のステータスと、お知らせ（トースト）、遊び方パネル。
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local notifyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local player = Players.LocalPlayer

local INK = Color3.fromRGB(40, 30, 20)
local PAPER = Color3.fromRGB(250, 244, 230)
local ACCENT = Color3.fromRGB(170, 50, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "RyokanHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.Font or Enum.Font.GothamBold
	t.TextColor3 = props.Color or INK
	t.TextSize = props.TextSize or 18
	t.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Size = props.Size
	t.Position = props.Position or UDim2.new()
	t.Text = props.Text or ""
	t.Parent = parent
	return t
end

-- ステータスパネル
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(230, 118)
panel.Position = UDim2.fromOffset(12, 60)
panel.BackgroundColor3 = PAPER
panel.BackgroundTransparency = 0.05
corner(panel, 10)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 2
stroke.Parent = panel
panel.Parent = gui

text(panel, { Text = "🏮 わたしの旅館", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), Color = ACCENT, TextSize = 20 })
local moneyLabel = text(panel, { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 36) })
local repLabel = text(panel, { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 60) })
local carryLabel = text(panel, { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 84) })

local function refreshMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("所持金")
	moneyLabel.Text = ("💰 所持金  ¥%d"):format(money and money.Value or 0)
end

local function refreshReputation()
	local rep = ReplicatedStorage:GetAttribute("Reputation") or Config.StartingReputation
	local full = math.clamp(math.round(rep), 0, 5)
	repLabel.Text = ("評判  %s%s  (%.1f)"):format(string.rep("★", full), string.rep("☆", 5 - full), rep)
end

local function refreshCarry()
	local item = player:GetAttribute("Carrying")
	local def = item and Config.Items[item]
	carryLabel.Text = "手持ち  " .. (def and def.Label or "なし")
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("所持金")
	money.Changed:Connect(refreshMoney)
	refreshMoney()
end)
ReplicatedStorage:GetAttributeChangedSignal("Reputation"):Connect(refreshReputation)
player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
refreshMoney()
refreshReputation()
refreshCarry()

-- 遊び方
local helpButton = Instance.new("TextButton")
helpButton.Size = UDim2.fromOffset(230, 30)
helpButton.Position = UDim2.fromOffset(12, 184)
helpButton.BackgroundColor3 = ACCENT
helpButton.TextColor3 = Color3.new(1, 1, 1)
helpButton.Font = Enum.Font.GothamBold
helpButton.TextSize = 16
helpButton.Text = "❓ 遊び方"
corner(helpButton)
helpButton.Parent = gui

local helpFrame = Instance.new("Frame")
helpFrame.Size = UDim2.fromOffset(330, 250)
helpFrame.Position = UDim2.fromOffset(12, 220)
helpFrame.BackgroundColor3 = PAPER
helpFrame.Visible = false
corner(helpFrame, 10)
helpFrame.Parent = gui
local helpPadding = Instance.new("UIPadding")
helpPadding.PaddingLeft = UDim.new(0, 12)
helpPadding.PaddingRight = UDim.new(0, 12)
helpPadding.PaddingTop = UDim.new(0, 10)
helpPadding.Parent = helpFrame
text(helpFrame, {
	Size = UDim2.fromScale(1, 1),
	TextSize = 15,
	Font = Enum.Font.Gotham,
	Text = table.concat({
		"① フロントでお客様を「チェックイン」",
		"② お客様が部屋でお願いをします",
		"　🍵 お茶 → 給湯室で受け取って運ぶ",
		"　🍱 お料理 → 厨房で受け取って運ぶ",
		"　🛏️ お布団 → 部屋の座卓で長押し",
		"③ 早く応えるほどチップが増えます",
		"④ 満足度が高いと宿泊料と評判アップ",
		"⑤ 評判が上がるとお客様が増えます",
		"⑥ お金がたまったら玄関横の掲示板で増築！",
	}, "\n"),
})
helpButton.Activated:Connect(function()
	helpFrame.Visible = not helpFrame.Visible
end)

-- お知らせ
local toastList = Instance.new("Frame")
toastList.BackgroundTransparency = 1
toastList.AnchorPoint = Vector2.new(0.5, 1)
toastList.Position = UDim2.new(0.5, 0, 1, -110)
toastList.Size = UDim2.fromOffset(460, 220)
toastList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastList

local toastCount = 0
notifyEvent.OnClientEvent:Connect(function(message)
	toastCount += 1
	local toast = Instance.new("TextLabel")
	toast.LayoutOrder = toastCount
	toast.Size = UDim2.fromOffset(460, 34)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 17
	toast.Text = message
	corner(toast)
	toast.Parent = toastList

	local children = toastList:GetChildren()
	local toasts = {}
	for _, child in children do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	task.delay(4, function()
		if not toast.Parent then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end)
