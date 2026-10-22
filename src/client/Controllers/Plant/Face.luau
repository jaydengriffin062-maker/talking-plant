--!strict
-- The plant's face: a SurfaceGui on a thin invisible plate in front of the head.
-- Eyes are CanvasGroups so eyelids clip to the round eye shape.

local TweenService = game:GetService("TweenService")

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Expressions = require(script.Parent.Expressions)

local OUTLINE = Color3.fromRGB(45, 85, 40)
local PUPIL = Color3.fromRGB(30, 35, 30)
local MOUTH = Color3.fromRGB(90, 35, 45)
local TONGUE = Color3.fromRGB(255, 120, 140)
local BLUSH = Color3.fromRGB(255, 140, 160)
local SICK_BLUSH = Color3.fromRGB(170, 160, 210)
local DROP = Color3.fromRGB(140, 205, 255)
local DIRT = Color3.fromRGB(110, 80, 50)

local TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLINK = TweenInfo.new(0.06, Enum.EasingStyle.Quad)

local EYE_X = { 0.32, 0.68 }
local EYE_Y = 0.4
local MOUTH_SIZE = Vector2.new(0.3, 0.2)
-- Upper lid travel: top = 1 brings the lid edge this far down the eye.
local LID_TRAVEL = 0.72
local CLOSED_BOTTOM = 0.3

export type Face = {
	setExpression: (self: Face, name: string) -> (),
	blink: (self: Face) -> (),
	setLook: (self: Face, x: number, y: number) -> (),
	setDirt: (self: Face, amount: number) -> (),
	talk: (self: Face, seconds: number) -> (),
	eyesClosed: (self: Face) -> boolean,
}

type Eye = {
	group: CanvasGroup,
	outline: Frame,
	pupil: Frame,
	top: Frame,
	bottom: Frame,
	dizzy: TextLabel,
}

local function corner(parent: Instance, radius: UDim?)
	Build.new("UICorner", { CornerRadius = radius or UDim.new(1, 0), Parent = parent })
end

local function frame(props: { [string]: any }): Frame
	props.BorderSizePixel = 0
	if props.AnchorPoint == nil then
		props.AnchorPoint = Vector2.zero
	end
	return Build.new("Frame", props)
end

local function circle(props: { [string]: any }): Frame
	local f = frame(props)
	corner(f)
	return f
end

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any })
	TweenService:Create(instance, info, goal):Play()
end

local function buildEye(parent: Instance, x: number, skin: Color3): Eye
	local outline = circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, EYE_Y),
		Size = UDim2.new(0.2, 6, 0.3, 6),
		BackgroundColor3 = OUTLINE,
		ZIndex = 1,
		Parent = parent,
	})
	local group: CanvasGroup = Build.new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, EYE_Y),
		Size = UDim2.fromScale(0.2, 0.3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
	corner(group)

	local pupil = circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.55, 0.55),
		BackgroundColor3 = PUPIL,
		Parent = group,
	})
	Build.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = pupil })
	circle({
		Position = UDim2.fromScale(0.2, 0.18),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = pupil,
	})

	local dizzy: TextLabel = Build.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		Text = "@",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = PUPIL,
		Visible = false,
		Parent = group,
	})

	local bottom = circle({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1.5, 1.3),
		BackgroundColor3 = skin,
		Parent = group,
	})

	local top = frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1.8, 1.2),
		BackgroundColor3 = skin,
		Parent = group,
	})
	-- Lash line along the lid's edge.
	frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = OUTLINE,
		Parent = top,
	})

	return { group = group, outline = outline, pupil = pupil, top = top, bottom = bottom, dizzy = dizzy }
end

-- An arc: the bottom (smile) or top (frown) half of an outlined ellipse.
local function buildArc(parent: Instance, lowerHalf: boolean): Frame
	local clip = frame({
		Position = UDim2.fromScale(-0.1, if lowerHalf then 0.5 else -0.15),
		Size = UDim2.fromScale(1.2, 0.65),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		Parent = parent,
	})
	local ring = circle({
		Position = UDim2.fromScale(0.1 / 1.2, if lowerHalf then -0.5 / 0.65 else 0.15 / 0.65),
		Size = UDim2.fromScale(1 / 1.2, 1 / 0.65),
		BackgroundTransparency = 1,
		Parent = clip,
	})
	Build.new("UIStroke", { Thickness = 5, Color = MOUTH, Parent = ring })
	return clip
end

local function buildMouth(parent: Instance): (Frame, { [string]: GuiObject }, Frame)
	local container = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(MOUTH_SIZE.X, MOUTH_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	local shapes: { [string]: GuiObject } = {}

	shapes.Smile = buildArc(container, true)
	shapes.Frown = buildArc(container, false)

	-- Grin: lower half of a filled ellipse with a tongue.
	local grinClip = frame({
		Position = UDim2.fromScale(0, 0.25),
		Size = UDim2.fromScale(1, 0.75),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		Parent = container,
	})
	local grin: CanvasGroup = Build.new("CanvasGroup", {
		Position = UDim2.fromScale(0, -0.8),
		Size = UDim2.fromScale(1, 1.6),
		BackgroundColor3 = MOUTH,
		BorderSizePixel = 0,
		Parent = grinClip,
	})
	corner(grin)
	circle({ Position = UDim2.fromScale(0.22, 0.74), Size = UDim2.fromScale(0.56, 0.4), BackgroundColor3 = TONGUE, Parent = grin })
	shapes.Grin = grinClip

	local open: CanvasGroup = Build.new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.95),
		BackgroundColor3 = MOUTH,
		BorderSizePixel = 0,
		Visible = false,
		Parent = container,
	})
	corner(open)
	circle({ Position = UDim2.fromScale(0.15, 0.68), Size = UDim2.fromScale(0.7, 0.45), BackgroundColor3 = TONGUE, Parent = open })
	shapes.Open = open

	local flat = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.14),
		BackgroundColor3 = MOUTH,
		Visible = false,
		Parent = container,
	})
	corner(flat)
	shapes.Flat = flat

	local wavy = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = container })
	for index, x in { 0.25, 0.5, 0.75 } do
		local bar = frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.3, 0.13),
			Rotation = if index % 2 == 1 then 30 else -30,
			BackgroundColor3 = MOUTH,
			Parent = wavy,
		})
		corner(bar)
	end
	shapes.Wavy = wavy

	local tongue = circle({
		Position = UDim2.fromScale(0.52, 0.62),
		Size = UDim2.fromScale(0.28, 0.5),
		BackgroundColor3 = TONGUE,
		ZIndex = 4,
		Visible = false,
		Parent = container,
	})

	return container, shapes, tongue
end

local Face = {}

function Face.new(plate: BasePart, skin: Color3): Face
	local gui: SurfaceGui = Build.new("SurfaceGui", {
		Name = "Face",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 120,
		LightInfluence = 0.35,
		ClipsDescendants = false,
		Parent = plate,
	})

	local blush: { Frame } = {}
	for _, x in { 0.17, 0.83 } do
		table.insert(
			blush,
			circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, 0.62),
				Size = UDim2.fromScale(0.15, 0.1),
				BackgroundColor3 = BLUSH,
				BackgroundTransparency = 1,
				Parent = gui,
			})
		)
	end

	local dirt: { Frame } = {}
	local dirtSpots = { { 0.14, 0.24, 0.12 }, { 0.8, 0.84, 0.1 }, { 0.56, 0.1, 0.09 }, { 0.26, 0.86, 0.13 } }
	for _, spot in dirtSpots do
		table.insert(
			dirt,
			circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(spot[1], spot[2]),
				Size = UDim2.fromScale(spot[3], spot[3] * 0.8),
				BackgroundColor3 = DIRT,
				BackgroundTransparency = 1,
				Parent = gui,
			})
		)
	end

	local eyes = { buildEye(gui, EYE_X[1], skin), buildEye(gui, EYE_X[2], skin) }

	local brows: { Frame } = {}
	for _, x in EYE_X do
		local brow = frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.17),
			Size = UDim2.fromScale(0.17, 0.045),
			BackgroundColor3 = OUTLINE,
			ZIndex = 3,
			Parent = gui,
		})
		corner(brow)
		table.insert(brows, brow)
	end

	local mouth, shapes, tongue = buildMouth(gui)

	local tear = circle({
		Position = UDim2.fromScale(0.26, 0.56),
		Size = UDim2.fromScale(0.05, 0.08),
		BackgroundColor3 = DROP,
		Visible = false,
		Parent = gui,
	})
	local sweat = circle({
		Position = UDim2.fromScale(0.86, 0.06),
		Size = UDim2.fromScale(0.06, 0.1),
		BackgroundColor3 = DROP,
		Visible = false,
		Parent = gui,
	})
	local anger: TextLabel = Build.new("TextLabel", {
		Position = UDim2.fromScale(0.8, -0.06),
		Size = UDim2.fromScale(0.2, 0.22),
		BackgroundTransparency = 1,
		Text = "💢",
		TextScaled = true,
		Visible = false,
		Parent = gui,
	})

	local current = Expressions.Neutral
	local currentMouth = "Smile"
	local look = Vector2.zero
	local blinking = false
	local talkingUntil = 0
	local talkThread: thread? = nil
	local spinTweens: { Tween } = {}

	local function showMouth(name: string)
		for shapeName, shape in shapes do
			shape.Visible = shapeName == name
		end
	end

	local function lidY(amount: number): number
		return amount * LID_TRAVEL
	end

	local function bottomAmount(e: Expressions.Expression): number
		return if e.top >= 0.95 then math.max(e.bottom, CLOSED_BOTTOM) else e.bottom
	end

	local function pupilPosition(index: number): UDim2
		local x = look.X
		if current.cross then
			x = if index == 1 then 0.8 else -0.8
		end
		return UDim2.fromScale(0.5 + x * 0.17, 0.55 + look.Y * 0.13)
	end

	local function setDizzy(on: boolean)
		for _, spin in spinTweens do
			spin:Cancel()
		end
		table.clear(spinTweens)
		for _, eye in eyes do
			eye.dizzy.Visible = on
			eye.pupil.Visible = not on
			if on then
				eye.dizzy.Rotation = 0
				local spin = TweenService:Create(eye.dizzy, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
				spin:Play()
				table.insert(spinTweens, spin)
			end
		end
	end

	local face = {}

	function face.setExpression(_self: Face, name: string)
		local e = Expressions[name]
		if not e then
			warn(`[Face] unknown expression {name}`)
			return
		end
		current = e
		local closed = e.top >= 0.95
		for index, eye in eyes do
			local mirror = if index == 1 then 1 else -1
			tween(eye.top, TWEEN, { Position = UDim2.fromScale(0.5, lidY(e.top)), Rotation = mirror * e.lidAngle })
			tween(eye.bottom, TWEEN, { Position = UDim2.fromScale(0.5, 1 - bottomAmount(e)) })
			tween(eye.pupil, TWEEN, { Size = UDim2.fromScale(e.pupil, e.pupil), Position = pupilPosition(index) })
			tween(eye.outline, TWEEN, { BackgroundTransparency = if closed then 1 else 0 })
			tween(brows[index], TWEEN, {
				Position = UDim2.fromScale(EYE_X[index], 0.17 + e.browY),
				Rotation = mirror * e.browAngle,
			})
		end
		setDizzy(e.dizzy == true)

		currentMouth = e.mouth
		if os.clock() >= talkingUntil then
			showMouth(currentMouth)
		end
		tween(mouth, TWEEN, { Size = UDim2.fromScale(MOUTH_SIZE.X * e.mouthScale, MOUTH_SIZE.Y * e.mouthScale) })
		tongue.Visible = e.tongue == true

		for _, cheek in blush do
			cheek.BackgroundColor3 = if e.sickly then SICK_BLUSH else BLUSH
			tween(cheek, TWEEN, { BackgroundTransparency = if e.blush or e.sickly then 0.35 else 1 })
		end
		tear.Visible = e.tear == true
		sweat.Visible = e.sweat == true
		anger.Visible = e.anger == true
	end

	function face.eyesClosed(_self: Face): boolean
		return current.top >= 0.7
	end

	function face.blink(self: Face)
		if blinking or self:eyesClosed() or current.dizzy then
			return
		end
		blinking = true
		for _, eye in eyes do
			tween(eye.top, BLINK, { Position = UDim2.fromScale(0.5, LID_TRAVEL) })
			tween(eye.bottom, BLINK, { Position = UDim2.fromScale(0.5, 1 - CLOSED_BOTTOM) })
		end
		task.delay(0.11, function()
			blinking = false
			-- Reopen to whatever expression is current now.
			local e = current
			for _, eye in eyes do
				tween(eye.top, BLINK, { Position = UDim2.fromScale(0.5, lidY(e.top)) })
				tween(eye.bottom, BLINK, { Position = UDim2.fromScale(0.5, 1 - bottomAmount(e)) })
			end
		end)
	end

	function face.setLook(_self: Face, x: number, y: number)
		look = Vector2.new(math.clamp(x, -1, 1), math.clamp(y, -1, 1))
		for index, eye in eyes do
			tween(eye.pupil, TWEEN, { Position = pupilPosition(index) })
		end
	end

	function face.setDirt(_self: Face, amount: number)
		for index, spot in dirt do
			-- Spots appear one by one as the plant gets dirtier.
			local visible = math.clamp(amount * #dirt - (index - 1), 0, 1)
			spot.BackgroundTransparency = 1 - visible * 0.8
		end
	end

	-- Flaps the mouth open and closed while the plant speaks.
	function face.talk(_self: Face, seconds: number)
		talkingUntil = os.clock() + seconds
		if talkThread then
			return
		end
		talkThread = task.spawn(function()
			local open = false
			while os.clock() < talkingUntil do
				open = not open
				showMouth(if open then "Open" else currentMouth)
				task.wait(0.11)
			end
			showMouth(currentMouth)
			talkThread = nil
		end)
	end

	local result = (face :: any) :: Face
	result:setExpression("Neutral")
	return result
end

return Face
