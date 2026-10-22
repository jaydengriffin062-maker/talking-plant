--!strict
-- The HUD: mood/needs button, coins, bottom navigation, care tray, talk panel,
-- banners and toasts. Everything hugs the screen edges so the plant stays visible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local NeedsMath = require(Shared.Util.NeedsMath)

local Build = require(script.Parent.Parent.Util.Build)
local StateController = require(script.Parent.StateController)
local ActionController = require(script.Parent.ActionController)
local InteractionController = require(script.Parent.InteractionController)
local Theme = require(script.Parent.UI.Theme)
local Widgets = require(script.Parent.UI.Widgets)
local NeedsPanel = require(script.Parent.UI.NeedsPanel)
local CareTray = require(script.Parent.UI.CareTray)
local TalkPanel = require(script.Parent.UI.TalkPanel)

local UIController = {}

local NAV = {
	{ id = "Home", icon = "🏠", label = "Home" },
	{ id = "Care", icon = "🍃", label = "Care" },
	{ id = "Games", icon = "🎮", label = "Games" },
	{ id = "Shop", icon = "🛒", label = "Shop" },
	{ id = "Customize", icon = "👕", label = "Style" },
}

local TOOL_HINTS: { [string]: string } = {
	Water = "Hold the watering can over the pot 💧",
	Feed = "Hold the bag over the pot 🌱",
	Clean = "Scrub your plant with the sponge 🧽",
}

local MOOD_EMOJI: { [string]: string } = {
	Happy = "😊",
	Neutral = "🙂",
	Sad = "😢",
	Thirsty = "🥵",
	Hungry = "😋",
	Tired = "🥱",
	Dirty = "🤢",
	Sleeping = "😴",
}

local gui: ScreenGui
local uiScale: UIScale
local needsPanel: NeedsPanel.NeedsPanel
local careTray: CareTray.CareTray
local talkPanel: TalkPanel.TalkPanel
local moodIcon: TextLabel
local happinessFill: Frame
local coinsLabel: TextLabel
local coinsPill: Frame
local navButtons: { [string]: TextButton } = {}
local banner: Frame
local bannerLabel: TextLabel
local bannerToken = 0
local toastLabel: TextLabel
local toastToken = 0
local stopCarePulse: (() -> ())? = nil
local shownCoins = 0

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 620), 0.62, 1.15)
end

local function setNavSelected(id: string)
	for navId, button in navButtons do
		button.BackgroundColor3 = if navId == id then Theme.Colors.Accent else Theme.Colors.Panel
	end
end

local function openCare(open: boolean)
	careTray:setOpen(open)
	if open then
		talkPanel:setOpen(false)
		setNavSelected("Care")
	else
		InteractionController.setTool(nil)
		setNavSelected("Home")
	end
end

local function openTalk(open: boolean)
	talkPanel:setOpen(open)
	if open then
		openCare(false)
	end
end

local function onCarePressed(kind: string)
	if kind == "Sleep" then
		InteractionController.setTool(nil)
		task.spawn(function()
			ActionController.care("Sleep")
		end)
		return
	end
	if InteractionController.getTool() == kind then
		InteractionController.setTool(nil)
	else
		InteractionController.setTool(kind)
	end
end

local function onNav(id: string)
	if id == "Home" then
		openCare(false)
		openTalk(false)
		needsPanel:setOpen(false)
	elseif id == "Care" then
		openCare(not careTray:isOpen())
	else
		UIController.toast("Coming soon! 🌱")
	end
end

local function buildTopBar()
	-- Mood button (top-left): opens the needs panel.
	local moodButton, icon = Widgets.iconButton({
		icon = "🙂",
		size = UDim2.fromOffset(76, 76),
		round = true,
		parent = gui,
	})
	moodButton.Position = UDim2.fromOffset(Theme.Gap + 4, Theme.Gap)
	moodIcon = icon
	local happinessBar = Build.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(60, 8),
		BackgroundColor3 = Theme.Colors.BarBackground,
		BorderSizePixel = 0,
		Parent = moodButton,
	})
	Widgets.corner(happinessBar, UDim.new(1, 0))
	happinessFill = Build.new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Theme.Colors.Happiness,
		BorderSizePixel = 0,
		Parent = happinessBar,
	})
	Widgets.corner(happinessFill, UDim.new(1, 0))
	moodButton.Activated:Connect(function()
		needsPanel:setOpen(not needsPanel:isOpen())
		local plant = StateController.plantNow()
		if plant then
			needsPanel:update(plant)
		end
	end)

	-- Coins (top-right).
	coinsPill = Widgets.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(Theme.Gap + 4), 0, Theme.Gap + 10),
		Size = UDim2.fromOffset(150, 52),
		Parent = gui,
	})
	Widgets.label({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 6), Text = "🪙", TextScaled = true, Parent = coinsPill })
	coinsLabel = Widgets.label({
		Size = UDim2.new(1, -60, 1, -12),
		Position = UDim2.fromOffset(52, 6),
		Text = "0",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coinsPill,
	})
end

local function buildNav()
	local nav = Widgets.panel({
		Name = "Nav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Gap),
		Size = UDim2.fromOffset(#NAV * 88 + 16, Theme.NavHeight),
		Parent = gui,
	})
	Build.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = nav,
	})
	for index, def in NAV do
		local button = Widgets.iconButton({
			icon = def.icon,
			label = def.label,
			size = UDim2.fromOffset(82, Theme.NavHeight - 12),
			parent = nav,
			layoutOrder = index,
		})
		button.Activated:Connect(function()
			onNav(def.id)
		end)
		navButtons[def.id] = button
	end
	setNavSelected("Home")

	-- Talk button sits bottom-right, above the nav.
	local talkButton = Widgets.iconButton({
		icon = "💬",
		size = UDim2.fromOffset(76, 76),
		round = true,
		color = Theme.Colors.Accent,
		parent = gui,
	})
	talkButton.AnchorPoint = Vector2.new(1, 1)
	talkButton.Position = UDim2.new(1, -(Theme.Gap + 4), 1, -(Theme.Gap * 2 + Theme.NavHeight))
	talkButton.Activated:Connect(function()
		openTalk(not talkPanel:isOpen())
	end)
end

local function buildMessages()
	banner = Widgets.panel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = gui,
	})
	Build.new("UIPadding", {
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		Parent = banner,
	})
	bannerLabel = Widgets.label({
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 28,
		TextWrapped = true,
		Text = "",
		Parent = banner,
	})
	Build.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200), Parent = bannerLabel })

	toastLabel = Widgets.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = Theme.Colors.AccentDark,
		TextTransparency = 1,
		Text = "",
		Parent = gui,
	})
end

-- Shows a message at the top of the screen. With no duration it stays until hidden.
function UIController.showBanner(text: string, duration: number?)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	banner.Visible = true
	Widgets.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, Theme.Gap + 10) }, Enum.EasingStyle.Back)
	if duration then
		task.delay(duration, function()
			if token == bannerToken then
				UIController.hideBanner()
			end
		end)
	end
end

function UIController.hideBanner()
	bannerToken += 1
	local token = bannerToken
	local slide = Widgets.tween(banner, 0.2, { Position = UDim2.new(0.5, 0, 0, -120) })
	slide.Completed:Once(function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

function UIController.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.3
	task.delay(1.6, function()
		if token == toastToken then
			Widgets.tween(toastLabel, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

function UIController.coinPop(amount: number)
	local pop = Widgets.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(Theme.Gap + 20), 0, Theme.Gap + 70),
		Size = UDim2.fromOffset(120, 36),
		Text = `+{amount}`,
		TextScaled = true,
		TextColor3 = Theme.Colors.Coin,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(150, 100, 20),
		Parent = gui,
	})
	Widgets.tween(pop, 1.2, { Position = pop.Position + UDim2.fromOffset(0, 40), TextTransparency = 1, TextStrokeTransparency = 1 })
	game:GetService("Debris"):AddItem(pop, 1.3)
	local scale: UIScale = coinsPill:FindFirstChildOfClass("UIScale") or Build.new("UIScale", { Parent = coinsPill })
	scale.Scale = 1.2
	Widgets.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UIController.openCare()
	openCare(true)
end

-- Draws attention to a care tool (and the Care tab while the tray is closed).
function UIController.highlightTool(kind: string, on: boolean)
	careTray:highlight(kind, on)
	if stopCarePulse then
		stopCarePulse()
		stopCarePulse = nil
	end
	if on then
		stopCarePulse = Widgets.pulse(navButtons.Care)
	end
end

local function render(state: Types.Snapshot)
	local plant = StateController.plantNow()
	if not plant then
		return
	end
	moodIcon.Text = MOOD_EMOJI[NeedsMath.mood(plant)] or "🙂"
	Widgets.tween(happinessFill, 0.4, { Size = UDim2.fromScale(math.max(NeedsMath.happiness(plant) / 100, 0.05), 1) })
	careTray:setAsleep(plant.asleep)
	talkPanel:setCanChat(state.canChat)
	if needsPanel:isOpen() then
		needsPanel:update(plant)
	end
	if state.coins ~= shownCoins then
		shownCoins = state.coins
		coinsLabel.Text = tostring(state.coins)
	end
end

function UIController.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	gui = Build.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	uiScale = Build.new("UIScale", { Parent = gui })

	needsPanel = NeedsPanel.new(gui)
	careTray = CareTray.new(gui, onCarePressed)
	talkPanel = TalkPanel.new(gui, function(text)
		task.spawn(ActionController.talk, text)
	end)
	buildTopBar()
	buildNav()
	buildMessages()
end

function UIController.start()
	updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	ActionController.CoinsEarned:Connect(UIController.coinPop)
	InteractionController.ToolChanged:Connect(function(kind)
		careTray:setActiveTool(kind)
		if kind then
			UIController.showBanner(TOOL_HINTS[kind] or "", 3)
		end
	end)
	StateController.Changed:Connect(render)

	local state = StateController.waitForLoad()
	render(state)
	-- Needs drift between server updates; keep the HUD honest.
	while true do
		task.wait(1)
		local latest = StateController.get()
		if latest then
			render(latest)
		end
	end
end

return UIController
