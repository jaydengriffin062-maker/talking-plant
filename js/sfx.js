// Tiny synthesized sound effects (no audio files). The AudioContext is created
// on the first user gesture, as browsers require.

let context = null;
let enabled = true;
let unlocked = false;

// Call from a user gesture; until then sounds are silently skipped.
export function unlockAudio() {
	unlocked = true;
	audioContext();
}

export function audioContext() {
	if (!unlocked) {
		return null;
	}
	if (!context) {
		const AudioContextClass = window.AudioContext || window.webkitAudioContext;
		if (!AudioContextClass) {
			return null;
		}
		context = new AudioContextClass();
	}
	if (context.state === "suspended") {
		context.resume().catch(() => {});
	}
	return context;
}

export function setSoundEnabled(on) {
	enabled = on;
	if (!on && "speechSynthesis" in window) {
		window.speechSynthesis.cancel();
	}
}

export function soundEnabled() {
	return enabled;
}

function tone({ freq, to = freq, duration = 0.15, type = "sine", volume = 0.18, delay = 0 }) {
	const ctx = audioContext();
	if (!ctx) {
		return;
	}
	const start = ctx.currentTime + delay;
	const osc = ctx.createOscillator();
	const gain = ctx.createGain();
	osc.type = type;
	osc.frequency.setValueAtTime(freq, start);
	osc.frequency.exponentialRampToValueAtTime(Math.max(to, 1), start + duration);
	gain.gain.setValueAtTime(0.0001, start);
	gain.gain.exponentialRampToValueAtTime(volume, start + 0.015);
	gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
	osc.connect(gain).connect(ctx.destination);
	osc.start(start);
	osc.stop(start + duration + 0.05);
}

function noise({ duration = 0.3, volume = 0.15, frequency = 1200, q = 0.8, delay = 0, sweepTo }) {
	const ctx = audioContext();
	if (!ctx) {
		return;
	}
	const start = ctx.currentTime + delay;
	const length = Math.ceil(ctx.sampleRate * duration);
	const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
	const data = buffer.getChannelData(0);
	for (let i = 0; i < length; i++) {
		data[i] = Math.random() * 2 - 1;
	}
	const source = ctx.createBufferSource();
	source.buffer = buffer;
	const filter = ctx.createBiquadFilter();
	filter.type = "bandpass";
	filter.frequency.setValueAtTime(frequency, start);
	if (sweepTo) {
		filter.frequency.exponentialRampToValueAtTime(sweepTo, start + duration);
	}
	filter.Q.value = q;
	const gain = ctx.createGain();
	gain.gain.setValueAtTime(volume, start);
	gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
	source.connect(filter).connect(gain).connect(ctx.destination);
	source.start(start);
}

const SOUNDS = {
	pop: () => tone({ freq: 500, to: 950, duration: 0.08, type: "triangle" }),
	boop: () => tone({ freq: 760, to: 380, duration: 0.16 }),
	knock: () => {
		tone({ freq: 180, to: 120, duration: 0.07, type: "triangle", volume: 0.25 });
		tone({ freq: 180, to: 120, duration: 0.07, type: "triangle", volume: 0.25, delay: 0.12 });
	},
	happy: () => [523, 659, 784].forEach((freq, i) => tone({ freq, duration: 0.12, type: "triangle", delay: i * 0.08 })),
	fanfare: () => [523, 659, 784, 1047].forEach((freq, i) => tone({ freq, duration: 0.2, type: "triangle", delay: i * 0.1 })),
	angry: () => tone({ freq: 170, to: 110, duration: 0.3, type: "sawtooth", volume: 0.08 }),
	grumble: () => tone({ freq: 140, to: 100, duration: 0.25, type: "square", volume: 0.05 }),
	sad: () => tone({ freq: 420, to: 210, duration: 0.5 }),
	laugh: () => [0, 1, 2, 3].forEach((i) => tone({ freq: 700 - i * 40, to: 560 - i * 40, duration: 0.09, delay: i * 0.11 })),
	purr: () => tone({ freq: 300, to: 360, duration: 0.25, type: "triangle", volume: 0.08 }),
	gulp: () => [0, 1, 2].forEach((i) => tone({ freq: 260, to: 520, duration: 0.09, delay: i * 0.16, volume: 0.15 })),
	munch: () => [0, 1, 2].forEach((i) => noise({ duration: 0.08, frequency: 900, volume: 0.25, delay: i * 0.14 })),
	splash: () => noise({ duration: 0.45, frequency: 2500, sweepTo: 600, volume: 0.12 }),
	sprinkle: () => noise({ duration: 0.25, frequency: 4000, volume: 0.06 }),
	scrub: () => noise({ duration: 0.18, frequency: 3000, q: 2, volume: 0.06 }),
	sparkle: () => [1319, 1568, 2093].forEach((freq, i) => tone({ freq, duration: 0.1, delay: i * 0.06, volume: 0.08 })),
	snore: () => tone({ freq: 130, to: 90, duration: 0.6, volume: 0.1 }),
	sneeze: () => {
		tone({ freq: 400, to: 700, duration: 0.5, volume: 0.06 });
		noise({ duration: 0.25, frequency: 1800, volume: 0.25, delay: 0.85 });
	},
	dizzy: () => tone({ freq: 600, to: 300, duration: 0.7, type: "triangle", volume: 0.08 }),
	rustle: () => noise({ duration: 0.3, frequency: 5000, volume: 0.05 }),
	tune: () => [659, 587, 523, 587, 659].forEach((freq, i) => tone({ freq, duration: 0.14, delay: i * 0.15, volume: 0.1 })),
	coin: () => {
		tone({ freq: 988, duration: 0.08, type: "square", volume: 0.06 });
		tone({ freq: 1319, duration: 0.25, type: "square", volume: 0.06, delay: 0.08 });
	},
	click: () => tone({ freq: 900, to: 700, duration: 0.04, type: "triangle", volume: 0.08 }),
	whoosh: () => noise({ duration: 0.3, frequency: 400, sweepTo: 2000, volume: 0.08 }),
};

export function play(name) {
	if (!enabled || !name) {
		return;
	}
	try {
		SOUNDS[name]?.();
	} catch {
		// Audio is a nicety; never let it break the game.
	}
}
