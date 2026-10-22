--!strict
-- Care tool models that follow the pointer: watering can, fertilizer bag, sponge.
-- Built in world axes (camera looks toward -Z, screen-right is +X). Each model's
-- pivot is the point that should sit over the pointer (spout tip, bag opening).

local Build = require(script.Parent.Parent.Parent.Util.Build)

export type Tool = {
	model: Model,
	-- Where the tool's pivot should be relative to the pointer's world point.
	offset: Vector3,
	-- Rotation (degrees about Z) while in use.
	useTilt: number,
	emitter: ParticleEmitter,
	useRate: number,
}

local Tools = {}

local function emitterAt(parent: BasePart, cframe: CFrame, props: { [string]: any }): ParticleEmitter
	local attachment = Build.new("Attachment", { Parent = parent })
	attachment.WorldCFrame = cframe
	local defaults: { [string]: any } = {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 0,
		EmissionDirection = Enum.NormalId.Front,
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, -30, 0),
		Size = NumberSequence.new(0.22, 0.12),
		LightEmission = 0.2,
		Parent = attachment,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Build.new("ParticleEmitter", defaults)
end

local function wateringCan(): Tool
	local model = Instance.new("Model")
	model.Name = "WateringCan"
	local blue = Color3.fromRGB(90, 170, 235)
	local dark = Color3.fromRGB(60, 130, 200)

	local body = Build.cylinder({ Color = blue, Parent = model }, CFrame.new(0, 0, 0), 1.4, 1.5)
	Build.cylinder({ Color = dark, Parent = model }, CFrame.new(0, 0.72, 0), 0.15, 1.6)
	local spoutAngle = math.rad(40)
	local spoutDirection = Vector3.new(-math.cos(spoutAngle), math.sin(spoutAngle), 0)
	local spoutCenter = Vector3.new(-1.15, 0.25, 0)
	Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 0.25, 0.25),
		CFrame = CFrame.new(spoutCenter) * CFrame.Angles(0, 0, -spoutAngle),
		Color = blue,
		Parent = model,
	})
	local tip = spoutCenter + spoutDirection * 0.8
	Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 0.45, 0.45),
		CFrame = CFrame.new(tip) * CFrame.Angles(0, 0, -spoutAngle),
		Color = dark,
		Parent = model,
	})
	Build.part({ Size = Vector3.new(0.18, 0.9, 0.2), CFrame = CFrame.new(0.95, 0.35, 0), Color = dark, Parent = model })
	Build.part({ Size = Vector3.new(1, 0.18, 0.2), CFrame = CFrame.new(0.45, 0.95, 0), Color = dark, Parent = model })

	local emitter = emitterAt(body, CFrame.lookAt(tip, tip + spoutDirection), {
		Color = ColorSequence.new(Color3.fromRGB(120, 195, 255)),
		Transparency = NumberSequence.new(0.15, 0.5),
	})
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(tip)
	return { model = model, offset = Vector3.new(0, 1.6, 0), useTilt = 35, emitter = emitter, useRate = 70 }
end

local function fertilizerBag(): Tool
	local model = Instance.new("Model")
	model.Name = "FertilizerBag"
	local bag = Build.part({
		Size = Vector3.new(1.2, 1.5, 0.6),
		CFrame = CFrame.new(0.6, -0.75, 0),
		Color = Color3.fromRGB(200, 160, 110),
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(1.25, 0.2, 0.65),
		CFrame = CFrame.new(0.6, -0.05, 0),
		Color = Color3.fromRGB(110, 180, 80),
		Parent = model,
	})
	local label = Build.new("SurfaceGui", {
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		LightInfluence = 0.5,
		Parent = bag,
	})
	Build.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🌱",
		TextScaled = true,
		Parent = label,
	})
	local opening = Vector3.new(-0.05, 0, 0)
	local emitter = emitterAt(bag, CFrame.lookAt(opening, opening + Vector3.new(0, -1, 0)), {
		Color = ColorSequence.new(Color3.fromRGB(120, 85, 50)),
		Size = NumberSequence.new(0.18, 0.12),
		LightEmission = 0,
	})
	model.PrimaryPart = bag
	model.WorldPivot = CFrame.new(opening)
	return { model = model, offset = Vector3.new(0, 1.4, 0), useTilt = 55, emitter = emitter, useRate = 50 }
end

local function sponge(): Tool
	local model = Instance.new("Model")
	model.Name = "Sponge"
	local body = Build.part({
		Size = Vector3.new(1.4, 0.8, 0.7),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(250, 220, 90),
		Material = Enum.Material.Sand,
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(1.4, 0.25, 0.7),
		CFrame = CFrame.new(0, 0.52, 0),
		Color = Color3.fromRGB(90, 170, 90),
		Parent = model,
	})
	local emitter = emitterAt(body, CFrame.new(0, 0, 0), {
		Color = ColorSequence.new(Color3.fromRGB(215, 240, 255)),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 2, 0),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1, 3),
		Size = NumberSequence.new(0.3, 0.45),
		Transparency = NumberSequence.new(0.2, 1),
	})
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0)
	return { model = model, offset = Vector3.new(0, 0, 0.6), useTilt = 0, emitter = emitter, useRate = 30 }
end

local BUILDERS: { [string]: () -> Tool } = {
	Water = wateringCan,
	Feed = fertilizerBag,
	Clean = sponge,
}

function Tools.build(kind: string): Tool?
	local builder = BUILDERS[kind]
	return if builder then builder() else nil
end

return Tools
