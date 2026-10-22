--!strict
-- Builds the plant's cosy room locally (each player sees only their own plant)
-- and owns the room lighting, including the night mode used while the plant sleeps.
--
-- Orientation: the camera sits at +Z looking toward -Z, so screen-right is +X.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Parent.Util.Build)

local RoomBuilder = {}

local STAND_TOP = 3.5
local ROOM_WIDTH = 30
local BACK_Z = -14
local FRONT_Z = 46
local WALL_HEIGHT = 34

local COLORS = {
	floor = Color3.fromRGB(205, 160, 115),
	wall = Color3.fromRGB(196, 228, 205),
	wainscot = Color3.fromRGB(150, 195, 165),
	trim = Color3.fromRGB(255, 250, 240),
	daySky = Color3.fromRGB(150, 210, 255),
	nightSky = Color3.fromRGB(28, 36, 82),
	curtain = Color3.fromRGB(255, 160, 170),
	wood = Color3.fromRGB(160, 110, 75),
	rug = Color3.fromRGB(250, 205, 120),
}

local folder: Folder
local windowGlass: BasePart
local windowLight: SurfaceLight
local lampLight: PointLight
local plantRoot: CFrame

local function buildWindow(parent: Instance)
	local center = CFrame.new(-7, 10, BACK_Z + 0.6)
	windowGlass = Build.part({
		Name = "WindowSky",
		Size = Vector3.new(8, 7, 0.2),
		CFrame = center,
		Color = COLORS.daySky,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	windowLight = Build.new("SurfaceLight", {
		Face = Enum.NormalId.Back,
		Angle = 70,
		Range = 22,
		Brightness = 1.4,
		Color = Color3.fromRGB(255, 244, 220),
		Parent = windowGlass,
	})
	-- Frame and cross bars.
	local bars = {
		{ Vector3.new(8.8, 0.5, 0.5), Vector3.new(0, 3.65, 0) },
		{ Vector3.new(8.8, 0.5, 0.5), Vector3.new(0, -3.65, 0) },
		{ Vector3.new(0.5, 7.8, 0.5), Vector3.new(4.15, 0, 0) },
		{ Vector3.new(0.5, 7.8, 0.5), Vector3.new(-4.15, 0, 0) },
		{ Vector3.new(8, 0.25, 0.3), Vector3.new(0, 0, 0.1) },
		{ Vector3.new(0.25, 7, 0.3), Vector3.new(0, 0, 0.1) },
	}
	for _, bar in bars do
		Build.part({ Size = bar[1], CFrame = center + bar[2], Color = COLORS.trim, Parent = parent })
	end
	Build.part({ Size = Vector3.new(9.6, 0.4, 1.4), CFrame = center + Vector3.new(0, -4.05, 0.5), Color = COLORS.trim, Parent = parent })
	for _, side in { -1, 1 } do
		Build.part({
			Size = Vector3.new(1.8, 9.5, 0.4),
			CFrame = center + Vector3.new(side * 5.1, -0.5, 0.6),
			Color = COLORS.curtain,
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
	end
end

local function buildShelf(parent: Instance)
	local shelfCF = CFrame.new(7.5, 8, BACK_Z + 1)
	Build.part({ Size = Vector3.new(7, 0.35, 1.8), CFrame = shelfCF, Color = COLORS.wood, Parent = parent })
	local books = {
		{ width = 0.5, height = 1.7, color = Color3.fromRGB(240, 110, 100) },
		{ width = 0.4, height = 1.4, color = Color3.fromRGB(110, 160, 240) },
		{ width = 0.6, height = 1.9, color = Color3.fromRGB(255, 210, 90) },
		{ width = 0.45, height = 1.5, color = Color3.fromRGB(160, 120, 220) },
	}
	local x = -3
	for _, book in books do
		Build.part({
			Size = Vector3.new(book.width, book.height, 1.2),
			CFrame = shelfCF * CFrame.new(x + book.width / 2, book.height / 2 + 0.17, 0),
			Color = book.color,
			Parent = parent,
		})
		x += book.width + 0.05
	end
	-- A tiny cactus friend on the shelf.
	local cactusBase = shelfCF * CFrame.new(1.8, 0.17, 0)
	Build.cylinder({ Color = Color3.fromRGB(220, 120, 80), Parent = parent }, cactusBase * CFrame.new(0, 0.35, 0), 0.7, 0.9)
	Build.ellipsoid({
		Size = Vector3.new(0.6, 1.2, 0.6),
		CFrame = cactusBase * CFrame.new(0, 1.2, 0),
		Color = Color3.fromRGB(90, 170, 90),
		Parent = parent,
	})

	-- Poster above the shelf.
	local poster = Build.part({
		Size = Vector3.new(4.5, 3.4, 0.15),
		CFrame = CFrame.new(7.5, 12.5, BACK_Z + 0.6),
		Color = Color3.fromRGB(255, 245, 225),
		Parent = parent,
	})
	local gui = Build.new("SurfaceGui", {
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0.6,
		Parent = poster,
	})
	Build.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🌱\nGROW BIG",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(80, 150, 90),
		Parent = gui,
	})
end

local function buildLamp(parent: Instance)
	local base = CFrame.new(-10, 0, -6)
	Build.cylinder({ Color = COLORS.wood, Parent = parent }, base * CFrame.new(0, 0.15, 0), 0.3, 2.2)
	Build.cylinder({ Color = COLORS.wood, Parent = parent }, base * CFrame.new(0, 5, 0), 10, 0.3)
	local shade = Build.cylinder({
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Fabric,
		Parent = parent,
	}, base * CFrame.new(0, 10.5, 0), 2.2, 3.2)
	lampLight = Build.new("PointLight", {
		Range = 18,
		Brightness = 0.4,
		Color = Color3.fromRGB(255, 200, 140),
		Shadows = true,
		Parent = shade,
	})
end

local function buildStand(parent: Instance)
	Build.cylinder({ Color = COLORS.rug, Material = Enum.Material.Fabric, Parent = parent }, CFrame.new(0, 0.05, 0), 0.1, 13)
	Build.cylinder({ Color = COLORS.wood, Parent = parent }, CFrame.new(0, 0.2, 0), 0.4, 3.2)
	Build.cylinder({ Color = COLORS.wood, Parent = parent }, CFrame.new(0, 1.6, 0), 2.8, 0.7)
	Build.cylinder({ Color = COLORS.wood, Parent = parent }, CFrame.new(0, STAND_TOP - 0.25, 0), 0.5, 6.2)
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(120, 110, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
end

function RoomBuilder.init()
	folder = Build.new("Folder", { Name = "Room" })

	Build.part({
		Name = "Floor",
		Size = Vector3.new(ROOM_WIDTH, 1, FRONT_Z - BACK_Z),
		CFrame = CFrame.new(0, -0.5, (FRONT_Z + BACK_Z) / 2),
		Color = COLORS.floor,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	Build.part({
		Name = "BackWall",
		Size = Vector3.new(ROOM_WIDTH, WALL_HEIGHT, 1),
		CFrame = CFrame.new(0, WALL_HEIGHT / 2, BACK_Z),
		Color = COLORS.wall,
		Parent = folder,
	})
	Build.part({
		Size = Vector3.new(ROOM_WIDTH, 3.6, 1.2),
		CFrame = CFrame.new(0, 1.8, BACK_Z + 0.1),
		Color = COLORS.wainscot,
		Parent = folder,
	})
	for _, side in { -1, 1 } do
		Build.part({
			Size = Vector3.new(1, WALL_HEIGHT, FRONT_Z - BACK_Z),
			CFrame = CFrame.new(side * ROOM_WIDTH / 2, WALL_HEIGHT / 2, (FRONT_Z + BACK_Z) / 2),
			Color = COLORS.wall,
			Parent = folder,
		})
	end

	buildWindow(folder)
	buildShelf(folder)
	buildLamp(folder)
	buildStand(folder)
	setupLighting()

	-- The plant's pot sits here; LookVector faces the camera.
	plantRoot = CFrame.lookAt(Vector3.new(0, STAND_TOP, 0), Vector3.new(0, STAND_TOP, 1))

	folder.Parent = workspace
end

function RoomBuilder.getPlantRoot(): CFrame
	return plantRoot
end

-- Dims the room while the plant sleeps.
function RoomBuilder.setNight(night: boolean)
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = if night then 20.5 else 14,
		Brightness = if night then 0.6 else 2,
		Ambient = if night then Color3.fromRGB(60, 60, 95) else Color3.fromRGB(120, 110, 100),
	}):Play()
	TweenService:Create(windowGlass, info, { Color = if night then COLORS.nightSky else COLORS.daySky }):Play()
	TweenService:Create(windowLight, info, { Brightness = if night then 0.2 else 1.4 }):Play()
	TweenService:Create(lampLight, info, { Brightness = if night then 1.6 else 0.4 }):Play()
end

return RoomBuilder
