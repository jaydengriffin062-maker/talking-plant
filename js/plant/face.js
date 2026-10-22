// Face state: eases numeric face values toward the current expression every
// frame and layers blinking, gaze and mouth flapping on top. The rig draws it.

import { Expressions } from "./expressions.js";
import { clamp } from "../needs.js";

const NUMERIC = ["top", "bottom", "lidAngle", "pupil", "browY", "browAngle", "mouthScale"];
const FLAGS = ["tear", "sweat", "anger", "dizzy", "tongue", "cross", "sickly"];
const BLINK_SECONDS = 0.16;
const EASE_RATE = 14;

const approach = (current, target, rate, dt) => current + (target - current) * (1 - Math.exp(-rate * dt));

export function createFace() {
	let target = Expressions.Neutral;
	const current = Object.fromEntries(NUMERIC.map((key) => [key, target[key]]));
	let blush = 0;
	let blinkStartedAt = -1;
	let talkingUntil = 0;
	const look = { x: 0, y: 0 };
	const lookCurrent = { x: 0, y: 0 };

	return {
		set(name) {
			const expression = Expressions[name];
			if (!expression) {
				console.warn(`[face] unknown expression ${name}`);
				return;
			}
			target = expression;
		},

		eyesClosed() {
			return target.top >= 0.7;
		},

		blink(t) {
			if (target.top < 0.7 && !target.dizzy && blinkStartedAt < 0) {
				blinkStartedAt = t;
			}
		},

		// x: -1 (screen-left) .. 1 (screen-right); y: -1 (up) .. 1 (down)
		setLook(x, y) {
			look.x = clamp(x, -1, 1);
			look.y = clamp(y, -1, 1);
		},

		talk(seconds, t) {
			talkingUntil = Math.max(talkingUntil, t + seconds);
		},

		step(dt, t) {
			for (const key of NUMERIC) {
				current[key] = approach(current[key], target[key], EASE_RATE, dt);
			}
			blush = approach(blush, target.blush || target.sickly ? 1 : 0, EASE_RATE, dt);
			lookCurrent.x = approach(lookCurrent.x, look.x, 12, dt);
			lookCurrent.y = approach(lookCurrent.y, look.y, 12, dt);

			let blink = 0;
			if (blinkStartedAt >= 0) {
				const progress = (t - blinkStartedAt) / BLINK_SECONDS;
				if (progress >= 1) {
					blinkStartedAt = -1;
				} else {
					blink = Math.sin(progress * Math.PI);
				}
			}

			let mouth = target.mouth;
			if (t < talkingUntil && Math.floor(t * 9) % 2 === 0) {
				mouth = mouth === "Open" ? "Flat" : "Open";
			}

			const params = { ...current, blush, blink, mouth, look: lookCurrent };
			for (const flag of FLAGS) {
				params[flag] = target[flag] === true;
			}
			return params;
		},
	};
}
