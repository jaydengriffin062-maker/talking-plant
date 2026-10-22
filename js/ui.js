// The HUD: mood/needs button, coins, sound toggle, bottom navigation, care tray,
// talk panel, banners and toasts. Everything hugs the screen edges.

import { Needs } from "./config/plant.js";
import { QuickPhrases } from "./config/talk.js";
import { happiness, mood as moodOf } from "./needs.js";
import * as State from "./state.js";
import { doCare, doTalk, doVoice, onCoins } from "./commands.js";
import { setTool, getTool, onToolChange } from "./interaction.js";
import { TOOLS } from "./tools.js";
import { play, setSoundEnabled } from "./sfx.js";
import { canRecord, startRecording, stopRecording, isRecording } from "./voice.js";

const NEED_ROWS = [
	{ key: "water", icon: "💧", label: "Water", color: "var(--water)" },
	{ key: "nutrients", icon: "🌱", label: "Nutrients", color: "var(--nutrients)" },
	{ key: "energy", icon: "⚡", label: "Energy", color: "var(--energy)" },
	{ key: "cleanliness", icon: "✨", label: "Clean", color: "var(--clean)" },
	{ key: "happiness", icon: "😊", label: "Happy", color: "var(--happy)" },
];

const MOOD_EMOJI = {
	Happy: "😊",
	Neutral: "🙂",
	Sad: "😢",
	Thirsty: "🥵",
	Hungry: "😋",
	Tired: "🥱",
	Dirty: "🤢",
	Sleeping: "😴",
};

const $ = (selector) => document.querySelector(selector);

let bannerTimer = null;
let toastTimer = null;
let shownCoins = null;
const needFills = {};

function setPanel(panel, open, button) {
	if (open) {
		panel.hidden = false;
		requestAnimationFrame(() => panel.classList.add("open"));
	} else {
		panel.classList.remove("open");
		setTimeout(() => {
			if (!panel.classList.contains("open")) {
				panel.hidden = true;
			}
		}, 250);
	}
	button?.setAttribute("aria-expanded", String(open));
}

const isOpen = (panel) => panel.classList.contains("open");

function selectNav(id) {
	document.querySelectorAll("#nav button").forEach((button) => {
		button.classList.toggle("selected", button.dataset.nav === id);
	});
}

function openCare(open) {
	setPanel($("#care-tray"), open);
	if (open) {
		openTalk(false);
		selectNav("Care");
	} else {
		setTool(null);
		selectNav("Home");
	}
}

function openTalk(open) {
	setPanel($("#talk-panel"), open, $("#talk-btn"));
	if (open) {
		setPanel($("#care-tray"), false);
		setTool(null);
		selectNav("Home");
	} else {
		$("#talk-input").blur();
	}
}

export function showBanner(text, duration) {
	clearTimeout(bannerTimer);
	const banner = $("#banner");
	banner.textContent = text;
	banner.classList.add("visible");
	if (duration) {
		bannerTimer = setTimeout(hideBanner, duration * 1000);
	}
}

export function hideBanner() {
	clearTimeout(bannerTimer);
	$("#banner").classList.remove("visible");
}

export function toast(text) {
	clearTimeout(toastTimer);
	const node = $("#toast");
	node.textContent = text;
	node.classList.add("visible");
	toastTimer = setTimeout(() => node.classList.remove("visible"), 1800);
}

function coinPop(amount) {
	const coins = $("#coins");
	const pop = document.createElement("div");
	pop.className = "coin-pop";
	pop.textContent = `+${amount}`;
	coins.appendChild(pop);
	pop.addEventListener("animationend", () => pop.remove());
	coins.classList.remove("bump");
	void coins.offsetWidth;
	coins.classList.add("bump");
}

export function openCareTray() {
	openCare(true);
}

// Pulses a care tool (and the Care tab) to draw attention.
export function highlightTool(kind, on) {
	const targets = [$(`[data-care="${kind}"]`), $('[data-nav="Care"]')];
	for (const target of targets) {
		target?.classList.toggle("pulse", on);
	}
}

function buildNeedsPanel() {
	const panel = $("#needs-panel");
	for (const row of NEED_ROWS) {
		const line = document.createElement("div");
		line.className = "need-row";
		line.innerHTML = `<span class="need-icon" aria-hidden="true">${row.icon}</span>
			<span class="bar" role="meter" aria-label="${row.label}" aria-valuemin="0" aria-valuemax="100"><span class="fill"></span></span>`;
		const fill = line.querySelector(".fill");
		fill.style.setProperty("--color", row.color);
		needFills[row.key] = { fill, meter: line.querySelector(".bar"), color: row.color };
		panel.appendChild(line);
	}
}

function render() {
	const profile = State.get();
	const plant = State.plantNow();
	const h = happiness(plant);
	$("#mood-icon").textContent = MOOD_EMOJI[moodOf(plant)] ?? "🙂";
	$("#happiness-fill").style.width = `${Math.max(h, 5)}%`;
	$("#sleep-icon").textContent = plant.asleep ? "☀️" : "🌙";
	$("#sleep-label").textContent = plant.asleep ? "Wake" : "Sleep";

	if (isOpen($("#needs-panel"))) {
		for (const row of NEED_ROWS) {
			const value = row.key === "happiness" ? h : plant.needs[row.key];
			const { fill, meter, color } = needFills[row.key];
			fill.style.width = `${Math.max(value, 4)}%`;
			fill.style.setProperty("--color", value < Needs.lowThreshold ? "var(--low)" : color);
			meter.setAttribute("aria-valuenow", String(Math.round(value)));
		}
	}

	if (profile.coins !== shownCoins) {
		shownCoins = profile.coins;
		$("#coin-count").textContent = profile.coins.toLocaleString();
	}
	const sound = profile.settings.sound;
	$("#sound-btn").textContent = sound ? "🔊" : "🔇";
	$("#sound-btn").setAttribute("aria-pressed", String(!sound));
	$("#sound-btn").setAttribute("aria-label", sound ? "Mute sound" : "Unmute sound");
}

function onCarePressed(kind, viaKeyboard) {
	if (kind === "Sleep") {
		setTool(null);
		doCare("Sleep");
		return;
	}
	// Keyboard users can't drag a tool, so the action happens immediately.
	if (viaKeyboard) {
		setTool(null);
		doCare(kind);
		return;
	}
	setTool(getTool() === kind ? null : kind);
}

function setupMic() {
	const mic = $("#mic-btn");
	if (!canRecord) {
		mic.hidden = true;
		return;
	}
	const begin = async (event) => {
		event.preventDefault();
		if (isRecording()) {
			return;
		}
		mic.setPointerCapture?.(event.pointerId);
		mic.classList.add("recording");
		showBanner("Listening... let go when you're done 🎤");
		try {
			await startRecording();
		} catch {
			mic.classList.remove("recording");
			showBanner("Microphone unavailable. Try typing instead!", 3);
		}
	};
	const end = async () => {
		if (!mic.classList.contains("recording")) {
			return;
		}
		mic.classList.remove("recording");
		hideBanner();
		const recording = await stopRecording();
		if (recording?.buffer) {
			doVoice(recording);
		}
	};
	mic.addEventListener("pointerdown", begin);
	mic.addEventListener("pointerup", end);
	mic.addEventListener("pointercancel", end);
	mic.addEventListener("contextmenu", (event) => event.preventDefault());
}

export function init() {
	buildNeedsPanel();

	const chips = $("#chips");
	for (const phrase of QuickPhrases) {
		const chip = document.createElement("button");
		chip.type = "button";
		chip.className = "chip";
		chip.textContent = phrase;
		chip.addEventListener("click", () => doTalk(phrase));
		chips.appendChild(chip);
	}

	$("#talk-form").addEventListener("submit", (event) => {
		event.preventDefault();
		const input = $("#talk-input");
		const text = input.value.trim();
		if (text) {
			input.value = "";
			doTalk(text);
		}
	});
	setupMic();

	$("#mood-btn").addEventListener("click", () => {
		const panel = $("#needs-panel");
		setPanel(panel, !isOpen(panel), $("#mood-btn"));
		requestAnimationFrame(render);
	});

	$("#talk-btn").addEventListener("click", () => openTalk(!isOpen($("#talk-panel"))));

	$("#sound-btn").addEventListener("click", () => {
		State.mutate((profile) => {
			profile.settings.sound = !profile.settings.sound;
		});
		setSoundEnabled(State.get().settings.sound);
		play("click");
	});

	document.querySelectorAll("[data-care]").forEach((button) => {
		button.addEventListener("click", (event) => onCarePressed(button.dataset.care, event.detail === 0));
	});

	document.querySelectorAll("[data-nav]").forEach((button) => {
		button.addEventListener("click", () => {
			play("click");
			const id = button.dataset.nav;
			if (id === "Home") {
				openCare(false);
				openTalk(false);
				setPanel($("#needs-panel"), false, $("#mood-btn"));
			} else if (id === "Care") {
				openCare(!isOpen($("#care-tray")));
			} else {
				toast("Coming soon! 🌱");
			}
		});
	});

	onToolChange((kind) => {
		document.querySelectorAll("[data-care]").forEach((button) => {
			button.classList.toggle("active", button.dataset.care === kind);
		});
		if (kind) {
			showBanner(TOOLS[kind].hint, 3);
		}
	});

	onCoins(coinPop);
	State.onChange(render);
	render();
	// Needs drift between actions; keep the HUD honest.
	setInterval(render, 1000);
}
