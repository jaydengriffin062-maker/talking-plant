// Tunable numbers for the plant's needs, care actions and touch interactions.

export const Needs = {
	max: 100,
	// Points lost per minute while the game is open.
	decayPerMinute: {
		water: 1.0,
		nutrients: 0.6,
		energy: 0.5,
		cleanliness: 0.4,
	},
	// While away, needs drain slower and never drop below the floor,
	// so a returning player finds a needy plant, never a wilted one.
	offlineMultiplier: 0.25,
	offlineFloor: 15,
	// Asleep: other needs drain slower and energy refills.
	sleepDecayMultiplier: 0.5,
	sleepEnergyRegenPerMinute: 6,
	affectionDecayPerMinute: 1.5,
	// Below this a need shows up as the plant's mood and a thought bubble.
	lowThreshold: 30,
};

export const Happiness = {
	needsWeight: 0.75,
	affectionWeight: 0.25,
	happyAt: 70,
	sadBelow: 40,
};

// Coins are only paid when the need was actually low, so spamming earns nothing.
export const Care = {
	Water: {
		need: "water",
		amount: 45,
		cooldown: 2,
		coinReward: 5,
		rewardMinDeficit: 15,
		fullAt: 95,
		reaction: "Drink",
		fullReaction: "NotThirsty",
		stat: "waters",
	},
	Feed: {
		need: "nutrients",
		amount: 40,
		cooldown: 2,
		coinReward: 5,
		rewardMinDeficit: 15,
		fullAt: 95,
		reaction: "Eat",
		fullReaction: "NotHungry",
		stat: "feeds",
	},
	Clean: {
		need: "cleanliness",
		amount: 100,
		cooldown: 2,
		coinReward: 5,
		rewardMinDeficit: 15,
		fullAt: 95,
		reaction: "Cleaned",
		fullReaction: "AlreadyClean",
		stat: "cleans",
	},
};

export const Sleep = {
	cooldown: 2,
	// The plant refuses bedtime when it still has this much energy.
	refuseAboveEnergy: 85,
};

export const Interactions = {
	Pet: { affection: 4, cooldown: 1.5 },
	Rub: { affection: 3, cooldown: 1.5 },
	Tickle: { affection: 3, cooldown: 2 },
	Poke: { affection: 0.5, cooldown: 0.3 },
	TapPot: { affection: 0, cooldown: 0.3 },
	Shake: { affection: -3, cooldown: 2 },
	PullLeaf: { affection: -5, cooldown: 2 },
};

// Rough handling wakes a sleeping plant (gentle petting does not).
export const WakingInteractions = new Set(["Poke", "Shake", "PullLeaf"]);

export const Tutorial = {
	startingWater: 20,
	coinReward: 100,
};

// Away at least this long (seconds) and the plant greets you on return.
export const welcomeBackAfter = 10 * 60;
