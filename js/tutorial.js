// First-time experience, about a minute long: meet the sprout, water it, get coins.
// The first successful watering marks the tutorial done and pays the reward.

import * as State from "./state.js";
import * as Plant from "./plant/controller.js";
import { showBanner, openCareTray, highlightTool } from "./ui.js";

const wait = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));
const done = () => State.get().tutorialDone;

export async function run() {
	if (done()) {
		return;
	}
	await wait(0.6);
	showBanner("Meet your new plant! 🌱", 3);
	Plant.react("Greet");
	await wait(3.2);
	if (done()) {
		return;
	}

	showBanner("Your plant looks thirsty... 💧");
	openCareTray();
	highlightTool("Water", true);
	await new Promise((resolve) => {
		const stop = State.onChange(() => {
			if (done()) {
				stop();
				resolve();
			}
		});
	});
	highlightTool("Water", false);

	await wait(2.5);
	showBanner("+100 coins! Now tap, rub & talk to your plant 💬", 5);
}
