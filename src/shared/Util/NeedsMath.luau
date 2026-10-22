--!strict
-- Pure needs math shared by server (authoritative) and client (prediction).
-- Needs are never ticked in a loop: they are stored with a timestamp and
-- brought up to date on demand with `advance`.

local Types = require(script.Parent.Parent.Types)
local PlantConfig = require(script.Parent.Parent.Config.PlantConfig)

export type Mood = "Sleeping" | "Thirsty" | "Hungry" | "Tired" | "Dirty" | "Happy" | "Neutral" | "Sad"

local Needs = PlantConfig.Needs
local Happiness = PlantConfig.Happiness

local NeedsMath = {}

local NEED_NAMES: { Types.NeedName } = { "water", "nutrients", "energy", "cleanliness" }
NeedsMath.NeedNames = NEED_NAMES

local LOW_NEED_MOODS: { [string]: Mood } = {
	water = "Thirsty",
	nutrients = "Hungry",
	energy = "Tired",
	cleanliness = "Dirty",
}

function NeedsMath.clonePlant(plant: Types.PlantState): Types.PlantState
	local copy = table.clone(plant)
	copy.needs = table.clone(plant.needs)
	return copy
end

-- Returns a copy of `plant` with needs decayed up to `now`.
-- `offline` applies the gentler offline rates and floor.
function NeedsMath.advance(plant: Types.PlantState, now: number, offline: boolean?): Types.PlantState
	local result = NeedsMath.clonePlant(plant)
	local minutes = math.max(0, now - plant.updatedAt) / 60
	result.updatedAt = math.max(now, plant.updatedAt)
	if minutes <= 0 then
		return result
	end

	local multiplier = if offline then Needs.OfflineMultiplier else 1
	if plant.asleep then
		multiplier *= Needs.SleepDecayMultiplier
	end

	for _, name in NEED_NAMES do
		local before = plant.needs[name] or Needs.Max
		local after
		if name == "energy" and plant.asleep then
			after = before + Needs.SleepEnergyRegenPerMinute * minutes
		else
			after = before - Needs.DecayPerMinute[name] * multiplier * minutes
			if offline then
				-- Never pull a need below the floor, but don't raise one already under it.
				after = math.max(after, math.min(before, Needs.OfflineFloor))
			end
		end
		result.needs[name] = math.clamp(after, 0, Needs.Max)
	end

	result.affection = math.max(0, plant.affection - Needs.AffectionDecayPerMinute * minutes)
	return result
end

function NeedsMath.happiness(plant: Types.PlantState): number
	local total = 0
	for _, name in NEED_NAMES do
		total += plant.needs[name] or 0
	end
	local average = total / #NeedsMath.NeedNames
	return math.clamp(average * Happiness.NeedsWeight + plant.affection * Happiness.AffectionWeight, 0, 100)
end

function NeedsMath.lowestNeed(plant: Types.PlantState): (Types.NeedName, number)
	local lowestIndex = 1
	local lowestValue = math.huge
	for index, name in NEED_NAMES do
		local value = plant.needs[name] or 0
		if value < lowestValue then
			lowestIndex, lowestValue = index, value
		end
	end
	return NEED_NAMES[lowestIndex], lowestValue
end

function NeedsMath.mood(plant: Types.PlantState): Mood
	if plant.asleep then
		return "Sleeping"
	end
	local name, value = NeedsMath.lowestNeed(plant)
	if value < Needs.LowThreshold then
		return LOW_NEED_MOODS[name]
	end
	local happiness = NeedsMath.happiness(plant)
	if happiness >= Happiness.HappyAt then
		return "Happy"
	elseif happiness < Happiness.SadBelow then
		return "Sad"
	end
	return "Neutral"
end

return NeedsMath
