// The player's save data, kept in localStorage. Gameplay mutates it only through
// `mutate`, which brings needs up to date first, then saves and notifies listeners.

import { Tutorial, welcomeBackAfter } from "./config/plant.js";
import { advance } from "./needs.js";

const STORAGE_KEY = "talking-plant/profile";
const SCHEMA_VERSION = 1;
// Hidden at least this long (seconds) counts as time away (offline decay rates).
const AWAY_AFTER = 60;

// [fromVersion] = (data) => data at fromVersion + 1
const MIGRATIONS = {};

export const now = () => Date.now() / 1000;

function template() {
	return {
		version: SCHEMA_VERSION,
		coins: 0,
		tutorialDone: false,
		plant: {
			// Starts thirsty so the tutorial's first action is watering.
			needs: { water: Tutorial.startingWater, nutrients: 80, energy: 90, cleanliness: 100 },
			affection: 0,
			asleep: false,
			updatedAt: now(),
		},
		stats: { waters: 0, feeds: 0, cleans: 0, pets: 0, talks: 0 },
		settings: { sound: true },
	};
}

// Fills in missing keys from the template and replaces values of the wrong type,
// so a hand-edited or old save can never crash the game.
function reconcile(data, defaults) {
	for (const [key, fallback] of Object.entries(defaults)) {
		const value = data[key];
		if (fallback !== null && typeof fallback === "object") {
			if (value === null || typeof value !== "object" || Array.isArray(value)) {
				data[key] = structuredClone(fallback);
			} else {
				reconcile(value, fallback);
			}
		} else if (typeof value !== typeof fallback || (typeof value === "number" && !Number.isFinite(value))) {
			data[key] = fallback;
		}
	}
}

function migrate(data) {
	let version = typeof data.version === "number" ? data.version : 1;
	while (version < SCHEMA_VERSION) {
		const step = MIGRATIONS[version];
		if (!step) {
			throw new Error(`missing save migration from v${version}`);
		}
		data = step(data);
		version += 1;
	}
	data.version = SCHEMA_VERSION;
	return data;
}

let profile = template();
let hiddenAt = null;
let saveTimer = null;
const listeners = new Set();

function emit() {
	for (const listener of listeners) {
		listener(profile);
	}
}

// Loads the save. Returns true if the player has been away long enough for a welcome back.
export function load() {
	let welcomeBack = false;
	try {
		const raw = localStorage.getItem(STORAGE_KEY);
		const parsed = raw ? JSON.parse(raw) : null;
		if (parsed && typeof parsed === "object") {
			const data = migrate(parsed);
			reconcile(data, template());
			welcomeBack = now() - data.plant.updatedAt >= welcomeBackAfter;
			// Time spent away decays at the gentler offline rate.
			data.plant = advance(data.plant, now(), true);
			profile = data;
		}
	} catch (error) {
		console.warn("[state] could not read save, starting fresh", error);
		profile = template();
	}
	saveNow();
	return welcomeBack;
}

export function saveNow() {
	clearTimeout(saveTimer);
	saveTimer = null;
	profile.plant = advance(profile.plant, now());
	try {
		localStorage.setItem(STORAGE_KEY, JSON.stringify(profile));
	} catch (error) {
		console.warn("[state] could not save", error);
	}
}

function scheduleSave() {
	if (!saveTimer) {
		saveTimer = setTimeout(saveNow, 500);
	}
}

export function get() {
	return profile;
}

// The plant with needs brought up to this moment (a copy).
export function plantNow() {
	return advance(profile.plant, now());
}

// Brings needs up to date, applies `change(profile)`, saves and notifies.
export function mutate(change) {
	profile.plant = advance(profile.plant, now());
	const result = change(profile);
	scheduleSave();
	emit();
	return result;
}

export function onChange(listener) {
	listeners.add(listener);
	return () => listeners.delete(listener);
}

// Call when the page is hidden/shown. Returns true when the player came back
// after long enough to deserve a welcome.
export function markHidden() {
	hiddenAt = now();
	saveNow();
}

export function markVisible() {
	if (hiddenAt === null) {
		return false;
	}
	const away = now() - hiddenAt;
	hiddenAt = null;
	if (away < AWAY_AFTER) {
		return false;
	}
	profile.plant = advance(profile.plant, now(), true);
	emit();
	return away >= welcomeBackAfter;
}

export function resetSave() {
	profile = template();
	saveNow();
	emit();
}
