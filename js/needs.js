// Pure needs math. Needs are never ticked in a loop: they are stored with a
// timestamp (seconds) and brought up to date on demand with `advance`.

import { Needs, Happiness } from "./config/plant.js";

export const NEED_NAMES = ["water", "nutrients", "energy", "cleanliness"];

const LOW_NEED_MOODS = {
	water: "Thirsty",
	nutrients: "Hungry",
	energy: "Tired",
	cleanliness: "Dirty",
};

export function clonePlant(plant) {
	return { ...plant, needs: { ...plant.needs } };
}

// Returns a copy of `plant` with needs decayed up to `now`.
// `offline` applies the gentler away-from-game rates and floor.
export function advance(plant, now, offline = false) {
	const result = clonePlant(plant);
	const minutes = Math.max(0, now - plant.updatedAt) / 60;
	result.updatedAt = Math.max(now, plant.updatedAt);
	if (minutes <= 0) {
		return result;
	}

	let multiplier = offline ? Needs.offlineMultiplier : 1;
	if (plant.asleep) {
		multiplier *= Needs.sleepDecayMultiplier;
	}

	for (const name of NEED_NAMES) {
		const before = plant.needs[name] ?? Needs.max;
		let after;
		if (name === "energy" && plant.asleep) {
			after = before + Needs.sleepEnergyRegenPerMinute * minutes;
		} else {
			after = before - Needs.decayPerMinute[name] * multiplier * minutes;
			if (offline) {
				// Never pull a need below the floor, but don't raise one already under it.
				after = Math.max(after, Math.min(before, Needs.offlineFloor));
			}
		}
		result.needs[name] = clamp(after, 0, Needs.max);
	}

	result.affection = Math.max(0, plant.affection - Needs.affectionDecayPerMinute * minutes);
	return result;
}

export function happiness(plant) {
	let total = 0;
	for (const name of NEED_NAMES) {
		total += plant.needs[name] ?? 0;
	}
	const average = total / NEED_NAMES.length;
	return clamp(average * Happiness.needsWeight + plant.affection * Happiness.affectionWeight, 0, 100);
}

export function lowestNeed(plant) {
	let lowestName = NEED_NAMES[0];
	let lowestValue = Infinity;
	for (const name of NEED_NAMES) {
		const value = plant.needs[name] ?? 0;
		if (value < lowestValue) {
			lowestName = name;
			lowestValue = value;
		}
	}
	return [lowestName, lowestValue];
}

export function mood(plant) {
	if (plant.asleep) {
		return "Sleeping";
	}
	const [name, value] = lowestNeed(plant);
	if (value < Needs.lowThreshold) {
		return LOW_NEED_MOODS[name];
	}
	const h = happiness(plant);
	if (h >= Happiness.happyAt) {
		return "Happy";
	}
	if (h < Happiness.sadBelow) {
		return "Sad";
	}
	return "Neutral";
}

export function clamp(value, min, max) {
	return Math.min(max, Math.max(min, value));
}
