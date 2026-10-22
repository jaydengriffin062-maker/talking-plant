--!strict
-- Turns raw mouse/touch input into plant interactions:
--   no tool:  tap head = poke, rub head = pet, rub leaf = rub, wiggle leaf = tickle,
--             drag leaf outward = pull, tap pot = look down, wiggle pot = shake,
--             tap elsewhere = the plant glances there
--   tool:     the tool follows the pointer; hold to pour (water/feed) or rub to clean

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Signal = require(Shared.Util.Signal)

local PlantController = require(script.Parent.PlantController)
local ActionController = require(script.Parent.ActionController)
local RoomBuilder = require(script.Parent.RoomBuilder)
local Tools = require(script.Parent.Interaction.Tools)

local InteractionController = {}

InteractionController.ToolChanged = Signal.new() :: Signal.Signal<string?>

local TAP_MAX_DISTANCE = 15
local TAP_MAX_TIME = 0.4
local PET_DISTANCE = 70
local RUB_DISTANCE = 90
local PET_INTERVAL = 0.9
local PULL_START = 25
local PULL_TRIGGER = 160
local WIGGLE_WINDOW = 1.5
local POUR_SECONDS = { Water = 1.0, Feed = 0.8 }
local CLEAN_DISTANCE = 600
-- Tools hover on a plane this far in front of the plant.
local TOOL_PLANE_OFFSET = 1.8

type Press = {
	zone: string,
	side: number,
	start: Vector2,
	last: Vector2,
	startedAt: number,
	distance: number,
	strokeDistance: number,
	lastDirection: number,
	reversals: number,
	firstReversalAt: number,
	leafDirection: number,
	pulling: boolean,
	handled: boolean,
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local press: Press? = nil
local pointer = Vector2.zero
local pointerDown = false
local activeTouch: InputObject? = nil
local lastStrokeAt = 0

local currentTool: string? = nil
local toolModels: { [string]: Tools.Tool } = {}
local pourTime = 0
local rubDistance = 0
local toolRequested = false
local currentTilt = 0

local function camera(): Camera
	return workspace.CurrentCamera :: Camera
end

local function rayAt(screen: Vector2): Ray
	return camera():ScreenPointToRay(screen.X, screen.Y)
end

-- The pointer projected onto a vertical plane in front of the plant.
local function pointOnToolPlane(screen: Vector2): Vector3?
	local root = RoomBuilder.getPlantRoot()
	local normal = root.LookVector
	local planePoint = root.Position + normal * TOOL_PLANE_OFFSET
	local ray = rayAt(screen)
	local denominator = ray.Direction:Dot(normal)
	if math.abs(denominator) < 1e-4 then
		return nil
	end
	local distance = (planePoint - ray.Origin):Dot(normal) / denominator
	return if distance > 0 then ray.Origin + ray.Direction * distance else nil
end

local function hitPlant(screen: Vector2): (string?, number)
	local ray = rayAt(screen)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, raycastParams)
	if not result then
		return nil, 0
	end
	local zone = result.Instance:GetAttribute("Zone")
	local side = result.Instance:GetAttribute("Side")
	return if typeof(zone) == "string" then zone else nil, if typeof(side) == "number" then side else 0
end

-- ── Gestures ────────────────────────────────────────────────────────────────

local function onPress(screen: Vector2)
	local zone, side = hitPlant(screen)
	if not zone then
		local point = pointOnToolPlane(screen)
		if point then
			PlantController.glanceAt(point)
		end
		return
	end
	local leafDirection = 0
	if zone == "Leaf" then
		local head = camera():WorldToScreenPoint(PlantController.getRig().head.Position)
		leafDirection = if screen.X >= head.X then 1 else -1
	end
	press = {
		zone = zone,
		side = side,
		start = screen,
		last = screen,
		startedAt = os.clock(),
		distance = 0,
		strokeDistance = 0,
		lastDirection = 0,
		reversals = 0,
		firstReversalAt = 0,
		leafDirection = leafDirection,
		pulling = false,
		handled = false,
	}
end

local function stroke(current: Press, kind: Types.InteractKind, threshold: number, delta: number)
	current.strokeDistance += delta
	if current.strokeDistance >= threshold then
		current.strokeDistance = 0
		current.handled = true
		local now = os.clock()
		if now - lastStrokeAt >= PET_INTERVAL then
			lastStrokeAt = now
			PlantController.gesture(kind)
		end
	end
end

local function wiggled(current: Press, count: number): boolean
	return current.reversals >= count and os.clock() - current.firstReversalAt < WIGGLE_WINDOW
end

local function onMove(screen: Vector2)
	local current = press
	if not current then
		return
	end
	local delta = screen - current.last
	current.last = screen
	current.distance += delta.Magnitude

	if math.abs(delta.X) > 3 then
		local direction = math.sign(delta.X)
		if current.lastDirection ~= 0 and direction ~= current.lastDirection then
			current.reversals += 1
			if current.reversals == 1 then
				current.firstReversalAt = os.clock()
			end
		end
		current.lastDirection = direction
	end

	if current.zone == "Head" then
		stroke(current, "Pet", PET_DISTANCE, delta.Magnitude)
	elseif current.zone == "Leaf" then
		local outward = (screen.X - current.start.X) * current.leafDirection
		if current.reversals == 0 and outward > PULL_START then
			current.pulling = true
			PlantController.setLeafPull(current.side, math.clamp((outward - PULL_START) / 250, 0, 0.6))
			if outward > PULL_TRIGGER and not current.handled then
				current.handled = true
				PlantController.gesture("PullLeaf")
			end
		elseif wiggled(current, 3) and not current.handled then
			current.handled = true
			PlantController.setLeafPull(current.side, 0)
			current.pulling = false
			PlantController.gesture("Tickle")
		elseif not current.pulling then
			stroke(current, "Rub", RUB_DISTANCE, delta.Magnitude)
		end
	elseif wiggled(current, 4) and not current.handled then
		current.handled = true
		PlantController.gesture("Shake")
	end
end

local function onRelease()
	local current = press
	press = nil
	if not current then
		return
	end
	if current.pulling then
		PlantController.setLeafPull(current.side, 0)
	end
	local isTap = os.clock() - current.startedAt < TAP_MAX_TIME and current.distance < TAP_MAX_DISTANCE
	if not isTap or current.handled then
		return
	end
	if current.zone == "Head" then
		PlantController.gesture("Poke")
	elseif current.zone == "Leaf" then
		PlantController.gesture("Tickle")
	else
		PlantController.gesture("TapPot")
	end
end

-- ── Tools ───────────────────────────────────────────────────────────────────

local function stopUsingTool()
	pourTime = 0
	rubDistance = 0
	PlantController.setToolInUse(nil)
	for _, tool in toolModels do
		tool.emitter.Rate = 0
	end
end

function InteractionController.getTool(): string?
	return currentTool
end

function InteractionController.setTool(kind: string?)
	if kind == currentTool then
		return
	end
	if currentTool then
		toolModels[currentTool].model.Parent = nil
	end
	stopUsingTool()
	toolRequested = false
	currentTilt = 0
	press = nil
	currentTool = kind

	if kind then
		local tool = toolModels[kind]
		if not tool then
			local built = Tools.build(kind)
			if not built then
				currentTool = nil
				InteractionController.ToolChanged:Fire(nil)
				return
			end
			tool = built
			toolModels[kind] = built
		end
		tool.model.Parent = workspace
		-- Start beside the plant so the tool is visible before the pointer moves.
		if not UserInputService.MouseEnabled then
			local viewport = camera().ViewportSize
			pointer = Vector2.new(viewport.X * 0.62, viewport.Y * 0.4)
		end
	else
		PlantController.setToolLook(nil)
	end
	InteractionController.ToolChanged:Fire(kind)
end

-- Is the pivot (spout tip, bag opening) over the pot?
local function overPot(position: Vector3): boolean
	local relative = RoomBuilder.getPlantRoot():PointToObjectSpace(position)
	return math.abs(relative.X) < 1.8 and relative.Y > 2.4 and relative.Y < 12
end

local function requestCare(action: Types.CareAction)
	toolRequested = true
	stopUsingTool()
	task.spawn(function()
		local result = ActionController.care(action)
		if result then
			InteractionController.setTool(nil)
		else
			toolRequested = false
		end
	end)
end

local function updateTool(dt: number)
	local kind = currentTool
	if not kind then
		return
	end
	local tool = toolModels[kind]
	local point = pointOnToolPlane(pointer)
	if not point then
		return
	end
	local pivot = point + tool.offset
	PlantController.setToolLook(pivot)

	local using = false
	if pointerDown and not toolRequested then
		if kind == "Clean" then
			using = select(1, hitPlant(pointer)) ~= nil
		else
			using = overPot(pivot)
		end
	end

	local tilt = if using then tool.useTilt else 0
	currentTilt += (tilt - currentTilt) * math.min(1, dt * 12)
	tool.model:PivotTo(CFrame.new(pivot) * CFrame.Angles(0, 0, math.rad(currentTilt)))
	tool.emitter.Rate = if using then tool.useRate else 0
	PlantController.setToolInUse(if using then kind else nil)

	if not using then
		return
	end
	if kind == "Clean" then
		if rubDistance >= CLEAN_DISTANCE then
			requestCare("Clean")
		end
	else
		pourTime += dt
		local needed = POUR_SECONDS[kind] or 1
		if pourTime >= needed then
			requestCare(kind :: Types.CareAction)
		end
	end
end

-- ── Input wiring ────────────────────────────────────────────────────────────

local function isPrimary(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or not isPrimary(input) or pointerDown then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = input
	end
	pointer = Vector2.new(input.Position.X, input.Position.Y)
	pointerDown = true
	if not currentTool then
		onPress(pointer)
	end
end

local function onInputChanged(input: InputObject)
	local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
	local isOurTouch = input.UserInputType == Enum.UserInputType.Touch and input == activeTouch
	if not isMouse and not isOurTouch then
		return
	end
	local previous = pointer
	pointer = Vector2.new(input.Position.X, input.Position.Y)
	if not pointerDown then
		return
	end
	if currentTool == "Clean" then
		if hitPlant(pointer) then
			rubDistance += (pointer - previous).Magnitude
		end
	elseif not currentTool then
		onMove(pointer)
	end
end

local function onInputEnded(input: InputObject)
	if not pointerDown then
		return
	end
	local endsTouch = input.UserInputType == Enum.UserInputType.Touch and input == activeTouch
	if not endsTouch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	pointerDown = false
	activeTouch = nil
	if currentTool then
		stopUsingTool()
	else
		onRelease()
	end
end

function InteractionController.start()
	raycastParams.FilterDescendantsInstances = { PlantController.getRig().model }
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService.RenderStepped:Connect(updateTool)
end

return InteractionController
