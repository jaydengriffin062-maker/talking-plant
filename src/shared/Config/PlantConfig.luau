--!strict
-- Tunable numbers for the plant's needs, care actions and touch interactions.
-- The client reads this for prediction and UI; the server's copy is authoritative.

local PlantConfig = {}

PlantConfig.Needs = {
	Max = 100,
	-- Points lost per minute while the player is online.
	DecayPerMinute = {
		water = 1.0,
		nutrients = 0.6,
		energy = 0.5,
		cleanliness = 0.4,
	} :: { [string]: number },
	-- While offline, needs drain slower and never drop below the floor,
	-- so a returning player finds a needy plant, never a wilted one.
	OfflineMultiplier = 0.25,
	OfflineFloor = 15,
	-- Asleep: other needs drain slower and energy refills.
	SleepDecayMultiplier = 0.5,
	SleepEnergyRegenPerMinute = 6,
	AffectionDecayPerMinute = 1.5,
	-- Below this a need shows up as the plant's mood and a thought bubble.
	LowThreshold = 30,
}

PlantConfig.Happiness = {
	NeedsWeight = 0.75,
	AffectionWeight = 0.25,
	HappyAt = 70,
	SadBelow = 40,
}

export type CareDef = {
	need: string,
	amount: number,
	cooldown: number,
	-- Coins are only paid when the need was actually low, so spamming earns nothing.
	coinReward: number,
	rewardMinDeficit: number,
	fullAt: number,
	reaction: string,
	fullReaction: string,
	stat: string,
}

PlantConfig.Care = {
	Water = {
		need = "water",
		amount = 45,
		cooldown = 2,
		coinReward = 5,
		rewardMinDeficit = 15,
		fullAt = 95,
		reaction = "Drink",
		fullReaction = "NotThirsty",
		stat = "waters",
	},
	Feed = {
		need = "nutrients",
		amount = 40,
		cooldown = 2,
		coinReward = 5,
		rewardMinDeficit = 15,
		fullAt = 95,
		reaction = "Eat",
		fullReaction = "NotHungry",
		stat = "feeds",
	},
	Clean = {
		need = "cleanliness",
		amount = 100,
		cooldown = 2,
		coinReward = 5,
		rewardMinDeficit = 15,
		fullAt = 95,
		reaction = "Cleaned",
		fullReaction = "AlreadyClean",
		stat = "cleans",
	},
} :: { [string]: CareDef }

PlantConfig.Sleep = {
	Cooldown = 2,
	-- The plant refuses bedtime when it still has this much energy.
	RefuseAboveEnergy = 85,
}

export type InteractionDef = { affection: number, cooldown: number }

PlantConfig.Interactions = {
	Pet = { affection = 4, cooldown = 1.5 },
	Rub = { affection = 3, cooldown = 1.5 },
	Tickle = { affection = 3, cooldown = 2 },
	Poke = { affection = 0.5, cooldown = 0.3 },
	TapPot = { affection = 0, cooldown = 0.3 },
	Shake = { affection = -3, cooldown = 2 },
	PullLeaf = { affection = -5, cooldown = 2 },
} :: { [string]: InteractionDef }

-- Rough handling wakes a sleeping plant (gentle petting does not).
PlantConfig.WakingInteractions = {
	Poke = true,
	Shake = true,
	PullLeaf = true,
} :: { [string]: boolean }

PlantConfig.Tutorial = {
	StartingWater = 20,
	CoinReward = 100,
}

-- Away at least this long (seconds) and the plant greets you on return.
PlantConfig.WelcomeBackAfter = 10 * 60

return PlantConfig
