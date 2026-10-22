// The plant's personality: mood -> resting face and body language, reactions,
// scripted motions, idle antics, blinking, gaze, and the per-frame animation loop.

import { Reactions, Moods, Idle, idleInterval, NeedIcons } from "../config/reactions.js";
import { Needs, WakingInteractions } from "../config/plant.js";
import { mood as moodOf, lowestNeed, clamp } from "../needs.js";
import * as State from "../state.js";
import { interact } from "../actions.js";
import { play } from "../sfx.js";
import { speak as speakAloud, playSqueaky } from "../voice.js";
import { buildRig } from "./rig.js";
import { createFace } from "./face.js";
import { Poses, POSE_KEYS } from "./poses.js";
import { createEffects } from "../effects.js";

const MAX_YAW = 35;
const MAX_PITCH = 30;
const POKE_WINDOW = 4;
const IDLE_AFTER_INTERACTION = 4;

const GESTURE_REACTIONS = {
	Pet: "Petted",
	Rub: "Rubbed",
	Tickle: "Laugh",
	Shake: "Dizzy",
	PullLeaf: "Ow",
	TapPot: "LookDown",
};

const TOOL_EXPRESSIONS = {
	Water: "Content",
	Feed: "Chomp",
	Clean: "Laugh",
};

const approach = (current, target, rate, dt) => current + (target - current) * (1 - Math.exp(-rate * dt));
const wait = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));
const seconds = () => performance.now() / 1000;
const pick = (list) => list[Math.floor(Math.random() * list.length)];

let rig;
let face;
let effects;

const currentPose = { ...Poses.Neutral };
let targetPose = Poses.Neutral;
const extras = { hop: 0, stretch: 0, lean: 0, sinkAdd: 0, lookYaw: 0, lookPitch: 0, pull: { 1: 0, [-1]: 0 } };
let hopVelocity = 0;
let stretchTarget = 0;
let leanTarget = 0;
let sinkTarget = 0;
let lookYawTarget = 0;
let lookPitchTarget = 0;
// Something to watch, in SVG coordinates: a point or a function returning one.
let motionLook = null;
let toolLook = null;

let currentMood = "Neutral";
let asleepShown = false;
let reactionToken = 0;
let reacting = false;
let toolInUse = false;
let lastInteractionAt = 0;
let pokeTimes = [];
let soilTimer = null;
let lastFrame = 0;

const alive = (token) => token === reactionToken;

function kick(strength) {
	hopVelocity = Math.max(hopVelocity, 7 * strength);
}

function speak(line, duration, { aloud = true } = {}) {
	effects.say(line, Math.max(duration, 1.2 + line.length * 0.035));
	face.talk(clamp(line.length * 0.05, 0.3, duration * 0.8), seconds());
	if (aloud) {
		speakAloud(line);
	}
}

function setPose(name) {
	if (Poses[name]) {
		targetPose = Poses[name];
	}
}

function applyMood() {
	const def = Moods[currentMood];
	face.set(def.expression);
	setPose(def.pose);
}

function resetMotion() {
	stretchTarget = 0;
	leanTarget = 0;
	sinkTarget = 0;
	lookYawTarget = 0;
	lookPitchTarget = 0;
	motionLook = null;
}

function setAsleep(asleep) {
	if (asleep === asleepShown) {
		return;
	}
	asleepShown = asleep;
	rig.setSleeping(asleep);
	effects.setSleeping(asleep);
	document.body.classList.toggle("night", asleep);
}

function refreshMood() {
	const plant = State.plantNow();
	rig.setDirt(clamp((70 - plant.needs.cleanliness) / 60, 0, 1));
	setAsleep(plant.asleep);

	const [need, value] = lowestNeed(plant);
	const showThought = value < Needs.lowThreshold && !plant.asleep && !reacting;
	effects.setThought(showThought ? NeedIcons[need] : null);

	const newMood = moodOf(plant);
	if (newMood !== currentMood) {
		currentMood = newMood;
		if (!reacting && !toolInUse) {
			applyMood();
		}
	}
}

// Scripted movements. Each checks `alive(token)` after waiting so a newer
// reaction can interrupt it cleanly.
const Motions = {
	async LookAround(token) {
		for (const [yaw, pitch] of [
			[30, 0],
			[-30, 0],
			[0, -15],
			[0, 0],
		]) {
			lookYawTarget = yaw;
			lookPitchTarget = pitch;
			await wait(0.75);
			if (!alive(token)) {
				return;
			}
		}
	},

	LookDown() {
		lookPitchTarget = 28;
	},

	Stare() {
		const head = rig.headPoint();
		motionLook = { x: head.x, y: head.y + 10 };
	},

	async Stretch(token) {
		stretchTarget = 0.8;
		await wait(1);
		if (alive(token)) {
			stretchTarget = 0;
		}
	},

	async Sneeze(token) {
		face.set("Surprised");
		leanTarget = 10;
		play("sneeze");
		speak("Ah... ah...", 0.9, { aloud: false });
		await wait(0.9);
		if (!alive(token)) {
			return;
		}
		face.set("Yawn");
		leanTarget = -18;
		kick(0.6);
		effects.burst("Pollen", 40);
		speak("ACHOO!", 0.8, { aloud: false });
		await wait(0.4);
		if (!alive(token)) {
			return;
		}
		leanTarget = 0;
		face.set("Content");
	},

	async CatchFly(token) {
		const fly = effects.spawnFly();
		motionLook = () => {
			const p = fly.position();
			return rig.toSvg(p.x, p.y);
		};
		face.set("Surprised");
		setPose("Neutral");
		play("rustle");

		for (let i = 0; i < 6; i++) {
			const head = rig.headPoint();
			const target = rig.toClient(head.x + (Math.random() - 0.5) * 300, head.y - 40 - Math.random() * 110);
			fly.moveTo(target.x, target.y, 400);
			await wait(0.42);
			if (!alive(token)) {
				fly.remove();
				return;
			}
		}

		face.set("Chomp");
		leanTarget = -20;
		kick(1);
		const head = rig.headPoint();
		const mouth = rig.toClient(head.x, head.y + 40);
		fly.moveTo(mouth.x, mouth.y, 150);
		await wait(0.18);
		fly.remove();
		play("munch");
		if (!alive(token)) {
			return;
		}
		leanTarget = 0;
		face.set("Content");
		speak("*gulp* ...crunchy.", 1.2, { aloud: false });
	},

	async FallInPot(token) {
		face.set("Surprised");
		play("whoosh");
		speak("Whoa—!", 0.8);
		sinkTarget = 1.3;
		await wait(1);
		if (!alive(token)) {
			return;
		}
		sinkTarget = 0;
		kick(1.2);
		play("pop");
		face.set("Excited");
		speak("I'm okay!!", 1);
	},

	async NodOff(token) {
		face.set("Sleeping");
		setPose("Sleeping");
		play("snore");
		await wait(2.2);
		if (!alive(token)) {
			return;
		}
		face.set("Surprised");
		setPose("Neutral");
		kick(1);
		play("pop");
		speak("I'M AWAKE!", 1.2);
	},
};

// Plays a reaction. `say` overrides the line; `aloud: false` keeps the voice quiet.
export function react(id, say, { aloud = true } = {}) {
	const def = Reactions[id];
	if (!def) {
		console.warn(`[plant] unknown reaction ${id}`);
		return;
	}
	reactionToken += 1;
	const token = reactionToken;
	reacting = true;
	resetMotion();
	effects.setThought(null);

	if (def.expression) {
		face.set(def.expression);
	}
	if (def.pose) {
		setPose(def.pose);
	}
	if (def.hop) {
		kick(def.hop);
	}
	play(def.sfx);
	const line = say ?? (def.say ? pick(def.say) : null);
	if (line) {
		speak(line, def.duration, { aloud });
	}
	if (def.effect) {
		effects.play(def.effect);
	}
	if (def.motion) {
		Motions[def.motion]?.(token);
	}

	setTimeout(() => {
		if (alive(token)) {
			reacting = false;
			resetMotion();
			applyMood();
			refreshMood();
		}
	}, def.duration * 1000);
}

// The plant repeats a voice recording back in a squeaky voice.
export function repeatRecording(buffer, transcript) {
	lastInteractionAt = seconds();
	const duration = playSqueaky(buffer);
	react("Echo", transcript || "🎶 blah blah blah! 🎶", { aloud: false });
	if (duration > 0) {
		face.talk(duration, seconds());
	}
	return duration;
}

// A touch gesture recognised by interaction.js.
export function gesture(kind) {
	lastInteractionAt = seconds();
	const wasAsleep = State.plantNow().asleep;
	interact(kind);

	if (wasAsleep) {
		if (WakingInteractions.has(kind)) {
			react("WokenGrumpy");
		} else if (kind !== "TapPot") {
			react("SleepSmile");
		}
		return;
	}

	if (kind === "Poke") {
		const t = seconds();
		pokeTimes = pokeTimes.filter((at) => t - at < POKE_WINDOW);
		pokeTimes.push(t);
		const count = pokeTimes.length;
		react(count >= 5 ? "Angry" : count >= 3 ? "Annoyed" : "Boop");
		return;
	}
	if (GESTURE_REACTIONS[kind]) {
		react(GESTURE_REACTIONS[kind]);
	}
}

// Stretches a leaf while it's being pulled (0 releases it).
export function setLeafPull(side, amount) {
	lastInteractionAt = seconds();
	const previous = extras.pull[side] ?? 0;
	extras.pull[side] = amount;
	if (amount > 0.08 && previous <= 0.08 && !reacting) {
		face.set("Surprised");
	} else if (amount === 0 && previous > 0) {
		kick(0.3);
		if (!reacting) {
			applyMood();
		}
	}
}

// The plant glances at a point the player clicked (client coordinates).
export function glanceAt(clientX, clientY) {
	lastInteractionAt = seconds();
	if (reacting) {
		return;
	}
	const point = rig.toSvg(clientX, clientY);
	motionLook = point;
	const token = reactionToken;
	setTimeout(() => {
		if (token === reactionToken && motionLook === point) {
			motionLook = null;
		}
	}, 1200);
}

// A care tool hovering near the plant (client coordinates; null = put away).
export function setToolLook(clientPoint) {
	toolLook = clientPoint ? rig.toSvg(clientPoint.x, clientPoint.y) : null;
}

// A care tool is being used on the plant right now (null = stopped).
export function setToolInUse(tool) {
	lastInteractionAt = seconds();
	const inUse = tool !== null;
	if (inUse === toolInUse) {
		return;
	}
	toolInUse = inUse;
	if (reacting) {
		return;
	}
	if (tool) {
		face.set(TOOL_EXPRESSIONS[tool] ?? "Happy");
		setPose("Happy");
	} else {
		applyMood();
	}
}

export function wetSoil() {
	rig.setSoilWet(true);
	clearTimeout(soilTimer);
	soilTimer = setTimeout(() => rig.setSoilWet(false), 8000);
}

export function getRig() {
	return rig;
}

export function getEffects() {
	return effects;
}

function currentLookPoint() {
	const target = motionLook ?? toolLook;
	return typeof target === "function" ? target() : target;
}

function updateGaze(dt) {
	let yaw = lookYawTarget;
	let pitch = lookPitchTarget;
	const point = currentLookPoint();
	if (point) {
		const head = rig.headPoint();
		const dx = point.x - head.x;
		const dy = point.y - head.y;
		yaw = clamp(dx / 5, -MAX_YAW, MAX_YAW);
		pitch = clamp(dy / 6, -MAX_PITCH, MAX_PITCH);
		face.setLook(dx / 180, dy / 180);
	} else {
		face.setLook(yaw / MAX_YAW, pitch / MAX_PITCH);
	}
	extras.lookYaw = approach(extras.lookYaw, yaw, 6, dt);
	extras.lookPitch = approach(extras.lookPitch, pitch, 6, dt);
}

function frame(timestamp) {
	const t = timestamp / 1000;
	const dt = Math.min(lastFrame ? t - lastFrame : 0.016, 0.05);
	lastFrame = t;

	for (const key of POSE_KEYS) {
		currentPose[key] = approach(currentPose[key], targetPose[key], 6, dt);
	}
	hopVelocity += (-140 * extras.hop - 9 * hopVelocity) * dt;
	extras.hop += hopVelocity * dt;
	extras.stretch = approach(extras.stretch, stretchTarget, 5, dt);
	extras.lean = approach(extras.lean, leanTarget, 10, dt);
	extras.sinkAdd = approach(extras.sinkAdd, sinkTarget, 8, dt);
	updateGaze(dt);

	rig.render({ pose: currentPose, extras, face: face.step(dt, seconds()), t });
	effects.update();
	requestAnimationFrame(frame);
}

function pickIdle() {
	const weights = Idle.map((entry) => entry.weight * (entry.moods?.[currentMood] ?? 1));
	const total = weights.reduce((sum, weight) => sum + weight, 0);
	let roll = Math.random() * total;
	for (let i = 0; i < Idle.length; i++) {
		roll -= weights[i];
		if (roll <= 0 && weights[i] > 0) {
			return Idle[i].id;
		}
	}
	return null;
}

function blinkLoop() {
	setTimeout(() => {
		face.blink(seconds());
		if (Math.random() < 0.2) {
			setTimeout(() => face.blink(seconds()), 260);
		}
		blinkLoop();
	}, (2.5 + Math.random() * 3) * 1000);
}

function idleLoop() {
	const delay = idleInterval.min + Math.random() * (idleInterval.max - idleInterval.min);
	setTimeout(() => {
		const quiet = seconds() - lastInteractionAt > IDLE_AFTER_INTERACTION;
		if (quiet && !reacting && !toolInUse && !asleepShown && !document.hidden) {
			const id = pickIdle();
			if (id) {
				react(id);
			}
		}
		idleLoop();
	}, delay * 1000);
}

export function init(svg, fxLayer) {
	rig = buildRig(svg);
	face = createFace();
	effects = createEffects(fxLayer, rig);
}

export function start() {
	refreshMood();
	applyMood();
	State.onChange(refreshMood);
	// Needs drift over time even when nothing happens.
	setInterval(refreshMood, 2000);
	requestAnimationFrame(frame);
	blinkLoop();
	idleLoop();
}
