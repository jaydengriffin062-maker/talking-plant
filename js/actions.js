// Game rules for care, touch and talk: cooldowns, rewards and need changes.
// Returns what happened; callers decide how the plant shows it (commands.js).

import { Care, Sleep, Interactions, WakingInteractions, Tutorial, Needs } from "./config/plant.js";
import { matchPhrase, StatusLines, maxLength } from "./config/talk.js";
import { lowestNeed, clamp } from "./needs.js";
import * as State from "./state.js";

const lastActionAt = new Map();

// True if `key` was used less than `seconds` ago; otherwise records the use.
function onCooldown(key, seconds) {
	const t = performance.now() / 1000;
	const last = lastActionAt.get(key);
	if (last !== undefined && t - last < seconds) {
		return true;
	}
	lastActionAt.set(key, t);
	return false;
}

function addAffection(plant, amount) {
	plant.affection = clamp(plant.affection + amount, 0, 100);
}

function toggleSleep() {
	if (onCooldown("Sleep", Sleep.cooldown)) {
		return { ok: false, reason: "cooldown" };
	}
	return State.mutate((profile) => {
		const plant = profile.plant;
		if (plant.asleep) {
			plant.asleep = false;
			return { ok: true, reaction: "WakeUp" };
		}
		if (plant.needs.energy > Sleep.refuseAboveEnergy) {
			return { ok: false, reason: "notSleepy", reaction: "NotSleepy" };
		}
		plant.asleep = true;
		return { ok: true, reaction: "FallAsleep" };
	});
}

// action: "Water" | "Feed" | "Clean" | "Sleep"
export function care(action) {
	if (action === "Sleep") {
		return toggleSleep();
	}
	const def = Care[action];
	if (!def) {
		return { ok: false, reason: "invalid" };
	}
	if (onCooldown(action, def.cooldown)) {
		return { ok: false, reason: "cooldown" };
	}
	return State.mutate((profile) => {
		const plant = profile.plant;
		if (plant.asleep) {
			return { ok: false, reason: "asleep", reaction: "SleepTalk" };
		}
		const before = plant.needs[def.need];
		if (before >= def.fullAt) {
			return { ok: false, reason: "full", reaction: def.fullReaction };
		}
		plant.needs[def.need] = Math.min(Needs.max, before + def.amount);

		let coins = Needs.max - before >= def.rewardMinDeficit ? def.coinReward : 0;
		let reaction = def.reaction;
		if (action === "Water" && !profile.tutorialDone) {
			profile.tutorialDone = true;
			coins += Tutorial.coinReward;
			reaction = "Celebrate";
		}
		profile.coins += coins;
		profile.stats[def.stat] = (profile.stats[def.stat] ?? 0) + 1;
		return { ok: true, reaction, coins };
	});
}

// kind: "Pet" | "Rub" | "Tickle" | "Poke" | "TapPot" | "Shake" | "PullLeaf"
// Returns { woke } so the caller can show a grumpy wake-up.
export function interact(kind) {
	const def = Interactions[kind];
	if (!def || onCooldown(`interact:${kind}`, def.cooldown)) {
		return { woke: false };
	}
	return State.mutate((profile) => {
		const plant = profile.plant;
		let woke = false;
		if (plant.asleep && WakingInteractions.has(kind)) {
			plant.asleep = false;
			woke = true;
		}
		addAffection(plant, def.affection);
		if (kind === "Pet") {
			profile.stats.pets = (profile.stats.pets ?? 0) + 1;
		}
		return { woke };
	});
}

function statusLine(plant) {
	const [need, value] = lowestNeed(plant);
	return value < 50 ? StatusLines[need] : StatusLines.fine;
}

// Returns { reaction, say? }. Unrecognised text is repeated back (Echo).
export function talk(rawText) {
	const text = String(rawText ?? "").trim().slice(0, maxLength);
	if (!text) {
		return { reaction: "Confused" };
	}
	if (onCooldown("talk", 0.6)) {
		return { reaction: "Busy" };
	}
	return State.mutate((profile) => {
		profile.stats.talks = (profile.stats.talks ?? 0) + 1;
		const phrase = matchPhrase(text);
		if (!phrase) {
			return { reaction: "Echo", say: text };
		}
		if (phrase.affection && !onCooldown("talkAffection", 3)) {
			addAffection(profile.plant, phrase.affection);
		}
		if (phrase.reaction === "Status") {
			return { reaction: "Status", say: statusLine(profile.plant) };
		}
		return { reaction: phrase.reaction };
	});
}
