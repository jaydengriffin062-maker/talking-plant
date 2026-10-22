// Entry point: load the save, build the plant, wire input and HUD, start the tutorial.

import * as State from "./state.js";
import * as Plant from "./plant/controller.js";
import * as Interaction from "./interaction.js";
import * as UI from "./ui.js";
import * as Tutorial from "./tutorial.js";
import { unlockAudio, setSoundEnabled } from "./sfx.js";

const welcomeBack = State.load();
setSoundEnabled(State.get().settings.sound);

Plant.init(document.getElementById("plant"), document.getElementById("fx"));
Interaction.init(document.getElementById("stage"), document.getElementById("tool-layer"));
UI.init();
Plant.start();

// Browsers only allow audio after a user gesture.
window.addEventListener("pointerdown", unlockAudio, { once: true, capture: true });
window.addEventListener("keydown", unlockAudio, { once: true, capture: true });

document.addEventListener("visibilitychange", () => {
	if (document.hidden) {
		State.markHidden();
	} else if (State.markVisible()) {
		Plant.react("WelcomeBack");
	}
});
window.addEventListener("pagehide", () => State.saveNow());

if (welcomeBack && State.get().tutorialDone) {
	setTimeout(() => Plant.react("WelcomeBack"), 800);
}
Tutorial.run();
