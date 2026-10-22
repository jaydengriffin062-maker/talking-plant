--!strict
-- Builds the plant from simple parts and poses it every frame from a handful of
-- numbers. All parts are anchored and moved with one BulkMoveTo call, so there is
-- no physics cost.
--
-- Local space: -Z faces the camera, +Y is up, local +X is screen-left.

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Poses = require(script.Parent.Poses)

local PlantRig = {}

PlantRig.SKIN = Color3.fromRGB(125, 205, 95)
local LEAF = Color3.fromRGB(85, 175, 75)
local STEM = Color3.fromRGB(95, 160, 70)
local POT = Color3.fromRGB(215, 120, 80)
local POT_RIM = Color3.fromRGB(190, 100, 65)
local SOIL = Color3.fromRGB(105, 70, 45)
local SOIL_WET = Color3.fromRGB(60, 38, 25)
local BLANKET = Color3.fromRGB(130, 170, 240)

local SOIL_TOP = 2.45
local STEM_LENGTH = 1.3
local STEM_DIAMETER = 0.35
local HEAD = Vector3.new(2.6, 2.3, 2.1)
local LEAF_SIZE = Vector3.new(1.9, 1.0, 0.16)
local SPROUT_SIZE = Vector3.new(0.6, 1.1, 0.12)

-- Live animation inputs that aren't part of a pose preset.
export type Extras = {
	hop: number,
	stretch: number,
	lean: number,
	sinkAdd: number,
	lookYaw: number,
	lookPitch: number,
	pull: { [number]: number },
}

export type Rig = {
	model: Model,
	head: BasePart,
	facePlate: BasePart,
	soil: BasePart,
	pot: BasePart,
	blanket: BasePart,
	leaves: { [number]: BasePart },
	update: (pose: Poses.Pose, extras: Extras, t: number) -> (),
	headCFrame: () -> CFrame,
	destroy: () -> (),
}

local function zone(part: BasePart, name: string, side: number?)
	part.CanQuery = true
	part:SetAttribute("Zone", name)
	if side then
		part:SetAttribute("Side", side)
	end
end

function PlantRig.build(root: CFrame, parent: Instance): Rig
	local model = Instance.new("Model")
	model.Name = "Plant"

	-- Static pot.
	local pot = Build.cylinder({ Name = "Pot", Color = POT, Parent = model }, root * CFrame.new(0, 1.1, 0), 2.2, 2.8)
	zone(pot, "Pot")
	local rim = Build.cylinder({ Name = "Rim", Color = POT_RIM, Parent = model }, root * CFrame.new(0, 2.225, 0), 0.55, 3.25)
	zone(rim, "Pot")
	local soil = Build.cylinder({
		Name = "Soil",
		Color = SOIL,
		Material = Enum.Material.Sand,
		Parent = model,
	}, root * CFrame.new(0, SOIL_TOP - 0.1, 0), 0.2, 2.75)
	zone(soil, "Soil")
	local blanket = Build.cylinder({
		Name = "Blanket",
		Color = BLANKET,
		Material = Enum.Material.Fabric,
		Transparency = 1,
		Parent = model,
	}, root * CFrame.new(0, 1.75, 0), 1.3, 3.45)

	-- Animated parts.
	local stem = Build.part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(STEM_LENGTH, STEM_DIAMETER, STEM_DIAMETER),
		Color = STEM,
		Parent = model,
	})
	local head = Build.ellipsoid({ Name = "Head", Size = HEAD, Color = PlantRig.SKIN, Parent = model })
	zone(head, "Head")
	local facePlate = Build.part({
		Name = "FacePlate",
		Size = Vector3.new(2.2, 1.95, 0.05),
		Transparency = 1,
		CastShadow = false,
		Parent = model,
	})

	local leaves: { [number]: BasePart } = {}
	local sprouts: { [number]: BasePart } = {}
	for _, side in { 1, -1 } do
		local leaf = Build.ellipsoid({ Name = "Leaf", Size = LEAF_SIZE, Color = LEAF, Parent = model })
		zone(leaf, "Leaf", side)
		leaves[side] = leaf
		local sprout = Build.ellipsoid({ Name = "Sprout", Size = SPROUT_SIZE, Color = LEAF, Parent = model })
		zone(sprout, "Leaf", side)
		sprouts[side] = sprout
	end

	model.PrimaryPart = pot
	model.Parent = parent

	local moving: { BasePart } = { stem, head, facePlate, leaves[1], leaves[-1], sprouts[1], sprouts[-1] }
	local targets: { CFrame } = table.create(#moving, CFrame.identity)
	local currentStem = STEM_LENGTH
	local currentLeafLength = { [1] = LEAF_SIZE.X, [-1] = LEAF_SIZE.X }
	local headCF = root

	local function update(pose: Poses.Pose, extras: Extras, t: number)
		local sway = math.rad(pose.swayAmp) * math.sin(t * pose.swaySpeed)
		local wobble = math.rad(pose.wobble)
		local roll = sway + wobble * math.sin(t * 7)
		local lean = math.rad(extras.lean) + wobble * math.cos(t * 7) * 0.6
		local base = root * CFrame.new(0, SOIL_TOP, 0) * CFrame.Angles(lean, 0, roll)

		local sink = math.clamp(pose.sink + extras.sinkAdd, 0, 1.4)
		local bob = pose.bobAmp * math.abs(math.sin(t * pose.bobSpeed))
		local stemLength = math.max(0.1, STEM_LENGTH * (1 - math.min(sink, 1)) + extras.hop + bob + extras.stretch)
		-- Past full retraction the head itself drops down into the pot.
		local headY = stemLength + HEAD.Y * 0.42 - sink * HEAD.Y * 0.35
		local jitter = if pose.tremble > 0 then (math.random() - 0.5) * pose.tremble else 0

		headCF = base
			* CFrame.new(jitter, headY, 0)
			* CFrame.Angles(-math.rad(pose.headPitch + extras.lookPitch), math.rad(extras.lookYaw), 0)

		if math.abs(stemLength - currentStem) > 0.01 then
			currentStem = stemLength
			stem.Size = Vector3.new(stemLength + 0.3, STEM_DIAMETER, STEM_DIAMETER)
		end
		targets[1] = base * CFrame.new(0, stemLength / 2 - 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
		targets[2] = headCF
		targets[3] = headCF * CFrame.new(0, 0, -HEAD.Z / 2 - 0.03)

		for index, side in { 1, -1 } do
			local flutter = pose.flutterAmp * math.sin(t * pose.flutterSpeed + (if side == 1 then 0 else 1.7))
			local angle = math.rad(pose.leafAngle + flutter)
			local length = LEAF_SIZE.X * (1 + (extras.pull[side] or 0))
			if math.abs(length - currentLeafLength[side]) > 0.01 then
				currentLeafLength[side] = length
				leaves[side].Size = Vector3.new(length, LEAF_SIZE.Y, LEAF_SIZE.Z)
			end
			local attach = headCF * CFrame.new(side * HEAD.X * 0.4, -HEAD.Y * 0.18, 0.1)
			targets[3 + index] = attach
				* CFrame.Angles(0, 0, side * angle)
				* CFrame.new(side * length / 2, 0, 0)
				* CFrame.Angles(math.rad(-20), 0, 0)

			local tilt = math.rad(math.clamp(28 - pose.leafAngle * 0.5 + flutter * 0.6, 5, 110))
			targets[5 + index] = headCF
				* CFrame.new(side * 0.12, HEAD.Y * 0.44, 0.05)
				* CFrame.Angles(0, 0, -side * tilt)
				* CFrame.new(0, SPROUT_SIZE.Y / 2, 0)
		end

		workspace:BulkMoveTo(moving, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local rig = {
		model = model,
		head = head,
		facePlate = facePlate,
		soil = soil,
		pot = pot,
		blanket = blanket,
		leaves = leaves,
		update = update,
		headCFrame = function()
			return headCF
		end,
		destroy = function()
			model:Destroy()
		end,
	}

	local neutral = Poses.Presets.Neutral
	update(neutral, { hop = 0, stretch = 0, lean = 0, sinkAdd = 0, lookYaw = 0, lookPitch = 0, pull = {} }, 0)
	return rig
end

PlantRig.SOIL_DRY = SOIL
PlantRig.SOIL_WET = SOIL_WET

return PlantRig
