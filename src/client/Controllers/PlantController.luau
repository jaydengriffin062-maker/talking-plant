--!strict
-- The plant's personality on the client: mood -> resting face and body language,
-- reactions, scripted motions, idle antics, blinking, gaze, and the per-frame
-- animation loop. Server-relevant gestures are forwarded via the Interact remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local NeedsMath = require(Shared.Util.NeedsMath)
local PlantConfig = require(Shared.Config.PlantConfig)
local ReactionConfig = require(Shared.Config.ReactionConfig)

local StateController = require(script.Parent.StateController)
local RoomBuilder = require(script.Parent.RoomBuilder)
local PlantRig = require(script.Parent.Plant.PlantRig)
local Face = require(script.Parent.Plant.Face)
local Effects = require(script.Parent.Plant.Effects)
local Poses = require(script.Parent.Plant.Poses)

local PlantController = {}

PlantController.ReactionStarted = Signal.new() :: Signal.Signal<string>

local MAX_YAW = 35
local MAX_PITCH = 30
local POKE_WINDOW = 4
local IDLE_AFTER_INTERACTION = 4

local GESTURE_REACTIONS: { [string]: string } = {
	Pet = "Petted",
	Rub = "Rubbed",
	Tickle = "Laugh",
	Shake = "Dizzy",
	PullLeaf = "Ow",
	TapPot = "LookDown",
}

local TOOL_EXPRESSIONS: { [string]: string } = {
	Water = "Content",
	Feed = "Chomp",
	Clean = "Laugh",
}

local rig: PlantRig.Rig
local face: Face.Face
local effects: Effects.Effects
local interactRemote: RemoteEvent

local currentPose: { [string]: number } = table.clone(Poses.Presets.Neutral :: any)
local targetPose: Poses.Pose = Poses.Presets.Neutral
local extras: PlantRig.Extras = {
	hop = 0,
	stretch = 0,
	lean = 0,
	sinkAdd = 0,
	lookYaw = 0,
	lookPitch = 0,
	pull = { [1] = 0, [-1] = 0 },
}
local hopVelocity = 0
local stretchTarget, leanTarget, sinkTarget = 0, 0, 0
local lookYawTarget, lookPitchTarget = 0, 0
local motionLook: (Vector3 | BasePart)? = nil
local toolLook: Vector3? = nil
local lastPupils = Vector2.zero

local mood: string = "Neutral"
local asleepShown = false
local reactionToken = 0
local reacting = false
local toolInUse = false
local lastInteractionAt = 0
local pokeTimes: { number } = {}
local soilToken = 0

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function alive(token: number): boolean
	return token == reactionToken
end

local function kick(strength: number)
	hopVelocity = math.max(hopVelocity, 7 * strength)
end

local function speak(line: string, duration: number)
	effects:say(line, math.max(duration, 1.2 + #line * 0.035))
	face:talk(math.clamp(#line * 0.05, 0.3, duration * 0.8))
end

local function setPose(name: string)
	local preset = Poses.Presets[name]
	if preset then
		targetPose = preset
	end
end

local function applyMood()
	local def = ReactionConfig.Moods[mood]
	face:setExpression(def.expression)
	setPose(def.pose)
end

local function resetMotion()
	stretchTarget, leanTarget, sinkTarget = 0, 0, 0
	lookYawTarget, lookPitchTarget = 0, 0
	motionLook = nil
end

local function setAsleep(asleep: boolean)
	if asleep == asleepShown then
		return
	end
	asleepShown = asleep
	TweenService:Create(rig.blanket, TweenInfo.new(0.6), { Transparency = if asleep then 0 else 1 }):Play()
	RoomBuilder.setNight(asleep)
	effects:setSleeping(asleep)
end

local function refreshMood()
	local plant = StateController.plantNow()
	if not plant then
		return
	end
	face:setDirt(math.clamp((70 - plant.needs.cleanliness) / 60, 0, 1))
	setAsleep(plant.asleep)

	local need, value = NeedsMath.lowestNeed(plant)
	local showThought = value < PlantConfig.Needs.LowThreshold and not plant.asleep and not reacting
	effects:setThought(if showThought then ReactionConfig.NeedIcons[need] else nil)

	local newMood = NeedsMath.mood(plant)
	if newMood ~= mood then
		mood = newMood
		if not reacting and not toolInUse then
			applyMood()
		end
	end
end

-- Scripted movements for reactions. Each checks `alive(token)` after waiting so
-- a newer reaction can interrupt it cleanly.
local Motions: { [string]: (token: number) -> () } = {}

function Motions.LookAround(token: number)
	local steps = { { 30, 0 }, { -30, 0 }, { 0, -15 }, { 0, 0 } }
	for _, target in steps do
		lookYawTarget, lookPitchTarget = target[1], target[2]
		task.wait(0.75)
		if not alive(token) then
			return
		end
	end
end

function Motions.LookDown(_token: number)
	lookPitchTarget = 28
end

function Motions.Stare(_token: number)
	local camera = workspace.CurrentCamera
	if camera then
		motionLook = camera.CFrame.Position
	end
end

function Motions.Stretch(token: number)
	stretchTarget = 0.8
	task.wait(1)
	if alive(token) then
		stretchTarget = 0
	end
end

function Motions.Sneeze(token: number)
	face:setExpression("Surprised")
	leanTarget = 10
	speak("Ah... ah...", 0.9)
	task.wait(0.9)
	if not alive(token) then
		return
	end
	face:setExpression("Yawn")
	leanTarget = -18
	kick(0.6)
	effects:burst("Pollen", 40)
	speak("ACHOO!", 0.8)
	task.wait(0.4)
	if not alive(token) then
		return
	end
	leanTarget = 0
	face:setExpression("Content")
end

function Motions.CatchFly(token: number)
	local fly = effects:spawnFly()
	game:GetService("Debris"):AddItem(fly, 6)
	motionLook = fly
	face:setExpression("Surprised")
	setPose("Neutral")

	local head = rig.headCFrame().Position
	for _ = 1, 6 do
		local offset = Vector3.new((math.random() - 0.5) * 6, 0.5 + math.random() * 2, 1.5 + math.random())
		TweenService:Create(fly, TweenInfo.new(0.4, Enum.EasingStyle.Sine), { CFrame = CFrame.new(head + offset) }):Play()
		task.wait(0.42)
		if not alive(token) then
			fly:Destroy()
			return
		end
	end

	face:setExpression("Chomp")
	leanTarget = -20
	kick(1)
	local mouth = rig.headCFrame() * CFrame.new(0, -0.4, -1)
	TweenService:Create(fly, TweenInfo.new(0.15), { CFrame = mouth }):Play()
	task.wait(0.18)
	fly:Destroy()
	if not alive(token) then
		return
	end
	leanTarget = 0
	face:setExpression("Content")
	speak("*gulp* ...crunchy.", 1.2)
end

function Motions.FallInPot(token: number)
	face:setExpression("Surprised")
	speak("Whoa—!", 0.8)
	sinkTarget = 1.3
	task.wait(1)
	if not alive(token) then
		return
	end
	sinkTarget = 0
	kick(1.2)
	face:setExpression("Excited")
	speak("I'm okay!!", 1)
end

function Motions.NodOff(token: number)
	face:setExpression("Sleeping")
	setPose("Sleeping")
	task.wait(2.2)
	if not alive(token) then
		return
	end
	face:setExpression("Surprised")
	setPose("Neutral")
	kick(1)
	speak("I'M AWAKE!", 1.2)
end

function PlantController.react(id: string, say: string?)
	local def = ReactionConfig.Reactions[id]
	if not def then
		warn(`[PlantController] unknown reaction {id}`)
		return
	end
	reactionToken += 1
	local token = reactionToken
	reacting = true
	resetMotion()
	effects:setThought(nil)

	if def.expression then
		face:setExpression(def.expression)
	end
	if def.pose then
		setPose(def.pose)
	end
	if def.hop then
		kick(def.hop)
	end
	local line = say or (if def.say then def.say[math.random(1, #def.say)] else nil)
	if line then
		speak(line, def.duration)
	end
	if def.effect then
		effects:play(def.effect)
	end
	local motion = def.motion and Motions[def.motion]
	if motion then
		task.spawn(motion, token)
	end
	PlantController.ReactionStarted:Fire(id)

	task.delay(def.duration, function()
		if alive(token) then
			reacting = false
			resetMotion()
			applyMood()
			refreshMood()
		end
	end)
end

-- A touch gesture recognised by InteractionController.
function PlantController.gesture(kind: Types.InteractKind)
	lastInteractionAt = os.clock()
	interactRemote:FireServer(kind)

	local plant = StateController.plantNow()
	if plant and plant.asleep then
		if PlantConfig.WakingInteractions[kind] then
			StateController.predict(function(p)
				p.asleep = false
			end)
			PlantController.react("WokenGrumpy")
		elseif kind ~= "TapPot" then
			PlantController.react("SleepSmile")
		end
		return
	end

	if kind == "Poke" then
		local now = os.clock()
		local recent = {}
		for _, at in pokeTimes do
			if now - at < POKE_WINDOW then
				table.insert(recent, at)
			end
		end
		table.insert(recent, now)
		pokeTimes = recent
		local count = #recent
		PlantController.react(if count >= 5 then "Angry" elseif count >= 3 then "Annoyed" else "Boop")
		return
	end

	local reaction = GESTURE_REACTIONS[kind]
	if reaction then
		PlantController.react(reaction)
	end
end

-- Stretches a leaf while it's being pulled (0 releases it).
function PlantController.setLeafPull(side: number, amount: number)
	lastInteractionAt = os.clock()
	local previous = extras.pull[side] or 0
	extras.pull[side] = amount
	if amount > 0.08 and previous <= 0.08 and not reacting then
		face:setExpression("Surprised")
	elseif amount == 0 and previous > 0 then
		kick(0.3)
		if not reacting then
			applyMood()
		end
	end
end

-- The plant glances at something the player clicked.
function PlantController.glanceAt(point: Vector3)
	lastInteractionAt = os.clock()
	if reacting then
		return
	end
	motionLook = point
	local token = reactionToken
	task.delay(1.2, function()
		if token == reactionToken and motionLook == point then
			motionLook = nil
		end
	end)
end

-- A care tool hovering near the plant (nil = put away).
function PlantController.setToolLook(point: Vector3?)
	toolLook = point
end

-- A care tool is being used on the plant right now.
function PlantController.setToolInUse(tool: string?)
	lastInteractionAt = os.clock()
	local inUse = tool ~= nil
	if inUse == toolInUse then
		return
	end
	toolInUse = inUse
	if reacting then
		return
	end
	if tool then
		face:setExpression(TOOL_EXPRESSIONS[tool] or "Happy")
		setPose("Happy")
	else
		applyMood()
	end
end

function PlantController.wetSoil()
	soilToken += 1
	local token = soilToken
	TweenService:Create(rig.soil, TweenInfo.new(0.5), { Color = PlantRig.SOIL_WET }):Play()
	task.delay(8, function()
		if token == soilToken then
			TweenService:Create(rig.soil, TweenInfo.new(4), { Color = PlantRig.SOIL_DRY }):Play()
		end
	end)
end

function PlantController.getRig(): PlantRig.Rig
	return rig
end

local function currentLookPoint(): Vector3?
	local target = motionLook or toolLook
	if typeof(target) == "Instance" then
		return if target.Parent then target.Position else nil
	end
	return target
end

local function updateGaze(dt: number)
	local yaw, pitch = lookYawTarget, lookPitchTarget
	local pupils: Vector2
	local point = currentLookPoint()
	if point then
		local relative = RoomBuilder.getPlantRoot():VectorToObjectSpace(point - rig.headCFrame().Position)
		local horizontal = math.sqrt(relative.X ^ 2 + relative.Z ^ 2)
		yaw = math.clamp(math.deg(math.atan2(-relative.X, -relative.Z)), -MAX_YAW, MAX_YAW)
		pitch = math.clamp(-math.deg(math.atan2(relative.Y, horizontal)), -MAX_PITCH, MAX_PITCH)
		-- Screen-right is local -X; GUI y grows downward.
		pupils = Vector2.new(math.clamp(-relative.X / 3, -1, 1), math.clamp(-relative.Y / 3, -1, 1))
	else
		-- Positive yaw turns the face toward screen-right.
		pupils = Vector2.new(yaw / MAX_YAW, pitch / MAX_PITCH)
	end
	extras.lookYaw = approach(extras.lookYaw, yaw, 6, dt)
	extras.lookPitch = approach(extras.lookPitch, pitch, 6, dt)
	if (pupils - lastPupils).Magnitude > 0.12 then
		lastPupils = pupils
		face:setLook(pupils.X, pupils.Y)
	end
end

local function step(dt: number)
	dt = math.min(dt, 0.05)
	for _, key in Poses.Keys do
		currentPose[key] = approach(currentPose[key], (targetPose :: any)[key], 6, dt)
	end
	hopVelocity += (-140 * extras.hop - 9 * hopVelocity) * dt
	extras.hop += hopVelocity * dt
	extras.stretch = approach(extras.stretch, stretchTarget, 5, dt)
	extras.lean = approach(extras.lean, leanTarget, 10, dt)
	extras.sinkAdd = approach(extras.sinkAdd, sinkTarget, 8, dt)
	updateGaze(dt)
	rig.update(currentPose :: any, extras, os.clock())
end

local function pickIdle(): string?
	local total = 0
	local weights: { number } = {}
	for index, entry in ReactionConfig.Idle do
		local multiplier = if entry.moods and entry.moods[mood] then entry.moods[mood] else 1
		weights[index] = entry.weight * multiplier
		total += weights[index]
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for index, entry in ReactionConfig.Idle do
		roll -= weights[index]
		if roll <= 0 then
			return entry.id
		end
	end
	return nil
end

local function blinkLoop()
	while true do
		task.wait(2.5 + math.random() * 3)
		face:blink()
		if math.random() < 0.2 then
			task.wait(0.25)
			face:blink()
		end
	end
end

local function idleLoop()
	local interval = ReactionConfig.IdleInterval
	while true do
		task.wait(interval.min + math.random() * (interval.max - interval.min))
		local quiet = os.clock() - lastInteractionAt > IDLE_AFTER_INTERACTION
		if quiet and not reacting and not toolInUse and not asleepShown then
			local id = pickIdle()
			if id then
				PlantController.react(id)
			end
		end
	end
end

function PlantController.init()
	interactRemote = Net.event("Interact")
	rig = PlantRig.build(RoomBuilder.getPlantRoot(), workspace)
	face = Face.new(rig.facePlate, PlantRig.SKIN)
	effects = Effects.new(rig.head)
end

function PlantController.start()
	RunService.RenderStepped:Connect(step)
	StateController.Changed:Connect(refreshMood)
	task.spawn(blinkLoop)
	task.spawn(idleLoop)

	local snapshot = StateController.waitForLoad()
	refreshMood()
	applyMood()
	if snapshot.welcomeBack then
		task.wait(0.8)
		PlantController.react("WelcomeBack")
	end

	-- Needs drift over time even without server updates.
	while true do
		task.wait(2)
		refreshMood()
	end
end

return PlantController
