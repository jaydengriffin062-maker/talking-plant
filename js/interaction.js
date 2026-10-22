// Turns mouse/touch input into plant interactions:
//   no tool:  tap head = poke, rub head = pet, rub leaf = rub, wiggle leaf = tickle,
//             drag leaf outward = pull, tap pot = knock, wiggle pot = shake,
//             tap elsewhere = the plant glances there
//   tool:     the tool follows the pointer; hold to pour (water/feed) or rub to clean

import * as Plant from "./plant/controller.js";
import { doCare } from "./commands.js";
import { TOOLS } from "./tools.js";
import { play } from "./sfx.js";

const TAP_MAX_DISTANCE = 15;
const TAP_MAX_TIME = 0.4;
const PET_DISTANCE = 70;
const RUB_DISTANCE = 90;
const PET_INTERVAL = 0.9;
const PULL_START = 25;
const PULL_TRIGGER = 160;
const WIGGLE_WINDOW = 1.5;
const POUR_SECONDS = { Water: 1.0, Feed: 0.8 };
const CLEAN_DISTANCE = 600;
// On touch screens the tool floats above the finger so it stays visible.
const TOUCH_LIFT = 70;

const seconds = () => performance.now() / 1000;

let stage;
let toolLayer;
let press = null;
const pointer = { x: 0, y: 0 };
let pointerDown = false;
let pointerId = null;
let pointerType = "mouse";
let lastStrokeAt = 0;

let currentTool = null;
let toolElement = null;
let pourTime = 0;
let rubDistance = 0;
let tilt = 0;
let lastParticleAt = 0;
let lastSoundAt = 0;
let lastToolFrame = 0;
const toolListeners = new Set();

function hitZone(x, y) {
	const element = document.elementFromPoint(x, y);
	const zoneElement = element?.closest?.("[data-zone]");
	if (!zoneElement || !Plant.getRig().svg.contains(zoneElement)) {
		return null;
	}
	return { zone: zoneElement.dataset.zone, side: Number(zoneElement.dataset.side || 0) };
}

// ── Gestures ────────────────────────────────────────────────────────────────

function onPress(x, y) {
	const hit = hitZone(x, y);
	if (!hit) {
		Plant.glanceAt(x, y);
		return;
	}
	let leafDirection = 0;
	if (hit.zone === "leaf") {
		const rig = Plant.getRig();
		const head = rig.headPoint();
		leafDirection = x >= rig.toClient(head.x, head.y).x ? 1 : -1;
	}
	press = {
		...hit,
		start: { x, y },
		last: { x, y },
		startedAt: seconds(),
		distance: 0,
		strokeDistance: 0,
		lastDirection: 0,
		reversals: 0,
		firstReversalAt: 0,
		leafDirection,
		pulling: false,
		handled: false,
	};
}

function stroke(current, kind, threshold, delta) {
	current.strokeDistance += delta;
	if (current.strokeDistance >= threshold) {
		current.strokeDistance = 0;
		current.handled = true;
		const t = seconds();
		if (t - lastStrokeAt >= PET_INTERVAL) {
			lastStrokeAt = t;
			Plant.gesture(kind);
		}
	}
}

const wiggled = (current, count) => current.reversals >= count && seconds() - current.firstReversalAt < WIGGLE_WINDOW;

function onMove(x, y) {
	const current = press;
	if (!current) {
		return;
	}
	const dx = x - current.last.x;
	const dy = y - current.last.y;
	const delta = Math.hypot(dx, dy);
	current.last = { x, y };
	current.distance += delta;

	if (Math.abs(dx) > 3) {
		const direction = Math.sign(dx);
		if (current.lastDirection !== 0 && direction !== current.lastDirection) {
			current.reversals += 1;
			if (current.reversals === 1) {
				current.firstReversalAt = seconds();
			}
		}
		current.lastDirection = direction;
	}

	if (current.zone === "head") {
		stroke(current, "Pet", PET_DISTANCE, delta);
	} else if (current.zone === "leaf") {
		const outward = (x - current.start.x) * current.leafDirection;
		if (current.reversals === 0 && outward > PULL_START) {
			current.pulling = true;
			Plant.setLeafPull(current.side, Math.min((outward - PULL_START) / 250, 0.6));
			if (outward > PULL_TRIGGER && !current.handled) {
				current.handled = true;
				Plant.gesture("PullLeaf");
			}
		} else if (wiggled(current, 3) && !current.handled) {
			current.handled = true;
			current.pulling = false;
			Plant.setLeafPull(current.side, 0);
			Plant.gesture("Tickle");
		} else if (!current.pulling) {
			stroke(current, "Rub", RUB_DISTANCE, delta);
		}
	} else if (wiggled(current, 4) && !current.handled) {
		current.handled = true;
		Plant.gesture("Shake");
	}
}

function onRelease() {
	const current = press;
	press = null;
	if (!current) {
		return;
	}
	if (current.pulling) {
		Plant.setLeafPull(current.side, 0);
	}
	const isTap = seconds() - current.startedAt < TAP_MAX_TIME && current.distance < TAP_MAX_DISTANCE;
	if (!isTap || current.handled) {
		return;
	}
	if (current.zone === "head") {
		Plant.gesture("Poke");
	} else if (current.zone === "leaf") {
		Plant.gesture("Tickle");
	} else {
		Plant.gesture("TapPot");
	}
}

// ── Tools ───────────────────────────────────────────────────────────────────

function stopUsingTool() {
	pourTime = 0;
	rubDistance = 0;
	Plant.setToolInUse(null);
}

export function getTool() {
	return currentTool;
}

export function onToolChange(listener) {
	toolListeners.add(listener);
}

export function setTool(kind) {
	if (kind === currentTool) {
		return;
	}
	toolElement?.remove();
	toolElement = null;
	stopUsingTool();
	press = null;
	tilt = 0;
	currentTool = kind && TOOLS[kind] ? kind : null;

	if (currentTool) {
		const def = TOOLS[currentTool];
		toolElement = document.createElement("div");
		toolElement.className = "tool";
		toolElement.innerHTML = def.svg;
		toolElement.style.width = `${def.width}px`;
		toolElement.style.height = `${def.height}px`;
		toolElement.style.transformOrigin = `${def.tip.x}px ${def.tip.y}px`;
		toolLayer.appendChild(toolElement);
		if (pointerType !== "mouse" || (pointer.x === 0 && pointer.y === 0)) {
			// Start beside the plant so the tool is visible before the pointer moves.
			const rig = Plant.getRig();
			const head = rig.headPoint();
			const spot = rig.toClient(head.x + 150, head.y - 40);
			pointer.x = spot.x;
			pointer.y = spot.y + (pointerType === "mouse" ? 0 : TOUCH_LIFT);
		}
		play("pop");
		requestAnimationFrame(updateTool);
	} else {
		Plant.setToolLook(null);
	}
	toolListeners.forEach((listener) => listener(currentTool));
}

function toolTip() {
	const lift = pointerType === "mouse" ? 0 : TOUCH_LIFT;
	return { x: pointer.x, y: pointer.y - lift };
}

function overPot(tip) {
	const rig = Plant.getRig();
	const pot = rig.pot.getBoundingClientRect();
	const soilY = rig.toClient(200, rig.soilY).y;
	return tip.x > pot.left + 12 && tip.x < pot.right - 12 && tip.y < soilY && tip.y > soilY - pot.height * 5;
}

function updateTool(timestamp) {
	if (!currentTool || !toolElement) {
		lastToolFrame = 0;
		return;
	}
	// Real elapsed time (capped for tab switches) so pouring takes the same time at any frame rate.
	const dt = Math.min(lastToolFrame ? (timestamp - lastToolFrame) / 1000 : 0.016, 0.25);
	lastToolFrame = timestamp;
	const def = TOOLS[currentTool];
	const tip = toolTip();
	Plant.setToolLook(tip);

	let using = false;
	if (pointerDown) {
		using = currentTool === "Clean" ? hitZone(pointer.x, pointer.y) !== null : overPot(tip);
	}
	const targetTilt = using ? def.useTilt : 0;
	tilt += (targetTilt - tilt) * Math.min(1, dt * 12);
	const wobble = currentTool === "Clean" && using ? Math.sin(timestamp / 50) * 8 : 0;
	toolElement.style.transform = `translate(${tip.x - def.tip.x}px, ${tip.y - def.tip.y}px) rotate(${tilt + wobble}deg)`;
	Plant.setToolInUse(using ? currentTool : null);

	if (using) {
		const now = seconds();
		if (now - lastParticleAt > 0.045) {
			lastParticleAt = now;
			Plant.getEffects().burst(def.particle, currentTool === "Clean" ? 1 : 2, tip);
		}
		if (now - lastSoundAt > (currentTool === "Clean" ? 0.25 : 0.5)) {
			lastSoundAt = now;
			play(def.sound);
		}
		if (currentTool === "Clean") {
			if (rubDistance >= CLEAN_DISTANCE) {
				finishTool("Clean");
				return;
			}
		} else {
			pourTime += dt;
			if (pourTime >= (POUR_SECONDS[currentTool] ?? 1)) {
				finishTool(currentTool);
				return;
			}
		}
	}
	requestAnimationFrame(updateTool);
}

function finishTool(action) {
	stopUsingTool();
	setTool(null);
	doCare(action);
}

// ── Input wiring ────────────────────────────────────────────────────────────

function onPointerDown(event) {
	if (pointerDown || (event.pointerType === "mouse" && event.button !== 0)) {
		return;
	}
	pointerDown = true;
	pointerId = event.pointerId;
	pointerType = event.pointerType;
	pointer.x = event.clientX;
	pointer.y = event.clientY;
	stage.setPointerCapture?.(event.pointerId);
	if (!currentTool) {
		onPress(event.clientX, event.clientY);
	}
}

function onPointerMove(event) {
	if (pointerDown && event.pointerId !== pointerId) {
		return;
	}
	if (!pointerDown && event.pointerType !== "mouse") {
		return;
	}
	pointerType = event.pointerType;
	const previous = { x: pointer.x, y: pointer.y };
	pointer.x = event.clientX;
	pointer.y = event.clientY;
	if (!pointerDown) {
		return;
	}
	if (currentTool === "Clean") {
		if (hitZone(pointer.x, pointer.y)) {
			rubDistance += Math.hypot(pointer.x - previous.x, pointer.y - previous.y);
		}
	} else if (!currentTool) {
		onMove(pointer.x, pointer.y);
	}
}

function onPointerUp(event) {
	if (!pointerDown || event.pointerId !== pointerId) {
		return;
	}
	pointerDown = false;
	pointerId = null;
	if (currentTool) {
		stopUsingTool();
	} else {
		onRelease();
	}
}

export function init(stageElement, toolLayerElement) {
	stage = stageElement;
	toolLayer = toolLayerElement;
	stage.addEventListener("pointerdown", onPointerDown);
	window.addEventListener("pointermove", onPointerMove);
	window.addEventListener("pointerup", onPointerUp);
	window.addEventListener("pointercancel", onPointerUp);
	window.addEventListener("keydown", (event) => {
		if (event.key === "Escape") {
			setTool(null);
		}
	});
}
