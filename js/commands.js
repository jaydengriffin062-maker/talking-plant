// Runs a game action and shows the result on the plant. The HUD, tools and
// voice input all go through here.

import { care, talk } from "./actions.js";
import * as Plant from "./plant/controller.js";
import { play } from "./sfx.js";

const coinListeners = new Set();

export function onCoins(listener) {
	coinListeners.add(listener);
}

export function doCare(action) {
	const result = care(action);
	if (result.reaction) {
		Plant.react(result.reaction);
	}
	if (action === "Water" && result.ok) {
		Plant.wetSoil();
	}
	if (result.coins > 0) {
		play("coin");
		coinListeners.forEach((listener) => listener(result.coins));
	}
	return result;
}

export function doTalk(text) {
	const result = talk(text);
	Plant.react(result.reaction, result.say);
	return result;
}

// The plant repeats the recording, then reacts if it understood the words.
export function doVoice({ buffer, transcript }) {
	const duration = Plant.repeatRecording(buffer, transcript);
	if (!transcript) {
		return;
	}
	const result = talk(transcript);
	if (result.reaction !== "Echo" && result.reaction !== "Busy") {
		setTimeout(() => Plant.react(result.reaction, result.say), duration * 1000 + 300);
	}
}
