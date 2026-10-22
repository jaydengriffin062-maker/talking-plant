// Visual feedback around the plant, drawn in a fixed overlay: speech bubble,
// thought bubble, floating emoji, particle bursts and the occasional fly.

const EMOJI_EFFECTS = {
	Hearts: { symbols: ["❤️", "💕", "💖"], count: 5 },
	Anger: { symbols: ["💢"], count: 2 },
	Stars: { symbols: ["⭐", "💫"], count: 4 },
	Notes: { symbols: ["🎵", "🎶"], count: 4 },
	Zzz: { symbols: ["💤"], count: 2 },
};

const PARTICLES = {
	Sparkles: { colors: ["#fff6a0", "#ffe066", "#ffffff"], shape: "star", speed: [90, 170], gravity: 60, life: 900 },
	Pollen: { colors: ["#ffe14d", "#ffd21f"], shape: "dot", speed: [120, 220], gravity: 120, life: 1000, direction: "down" },
	Bubbles: { colors: ["#d8f0ff", "#bfe6ff"], shape: "bubble", speed: [30, 80], gravity: -80, life: 1400 },
	Confetti: { colors: ["#ff6e82", "#ffdc5a", "#6ec8ff", "#96e678", "#c49bff"], shape: "rect", speed: [260, 420], gravity: 520, life: 1800, direction: "up" },
	Water: { colors: ["#7cc4ff", "#a6d8ff"], shape: "drop", speed: [10, 30], gravity: 900, life: 650, direction: "down" },
	Soil: { colors: ["#7a5232", "#5e3e26"], shape: "dot", speed: [10, 30], gravity: 900, life: 650, direction: "down" },
};

const random = (min, max) => min + Math.random() * (max - min);

export function createEffects(layer, rig) {
	const speech = document.createElement("div");
	speech.className = "speech";
	speech.setAttribute("role", "status");
	speech.setAttribute("aria-live", "polite");
	layer.appendChild(speech);

	const thought = document.createElement("div");
	thought.className = "thought";
	layer.appendChild(thought);

	let speechTimer = null;
	let sleepTimer = null;

	function headClient(offsetX = 0, offsetY = 0) {
		const head = rig.headPoint();
		return rig.toClient(head.x + offsetX, head.y + offsetY);
	}

	function place(node, x, y) {
		node.style.transform = `translate(${x}px, ${y}px)`;
	}

	function particle(kind, x, y) {
		const def = PARTICLES[kind];
		const node = document.createElement("div");
		node.className = `particle particle-${def.shape}`;
		node.style.setProperty("--color", def.colors[Math.floor(Math.random() * def.colors.length)]);
		layer.appendChild(node);

		let angle = random(0, Math.PI * 2);
		if (def.direction === "up") {
			angle = random(-Math.PI * 0.85, -Math.PI * 0.15);
		} else if (def.direction === "down") {
			angle = random(Math.PI * 0.3, Math.PI * 0.7);
		}
		const speed = random(def.speed[0], def.speed[1]);
		const seconds = def.life / 1000;
		const dx = Math.cos(angle) * speed * seconds;
		const dy = Math.sin(angle) * speed * seconds + 0.5 * def.gravity * seconds * seconds;
		const spin = random(-360, 360);
		node.animate(
			[
				{ transform: `translate(${x}px, ${y}px) rotate(0deg) scale(1)`, opacity: 1 },
				{ transform: `translate(${x + dx * 0.6}px, ${y + dy * 0.45}px) rotate(${spin * 0.6}deg) scale(1)`, opacity: 1, offset: 0.6 },
				{ transform: `translate(${x + dx}px, ${y + dy}px) rotate(${spin}deg) scale(0.6)`, opacity: 0 },
			],
			{ duration: def.life, easing: "cubic-bezier(.2,.6,.4,1)" },
		).onfinish = () => node.remove();
	}

	return {
		// Repositions bubbles that follow the head (called every frame).
		update() {
			const scale = rig.scale();
			if (speech.classList.contains("visible")) {
				const top = headClient(0, -rig.headRadius - 70);
				place(speech, top.x, top.y);
			}
			if (thought.classList.contains("visible")) {
				const side = headClient(rig.headRadius + 40, -rig.headRadius * 0.6);
				place(thought, side.x, side.y);
			}
			layer.style.setProperty("--plant-scale", String(scale));
		},

		say(text, seconds) {
			clearTimeout(speechTimer);
			speech.textContent = text;
			speech.classList.remove("visible");
			void speech.offsetWidth; // restart the pop-in animation
			speech.classList.add("visible");
			this.update();
			speechTimer = setTimeout(() => speech.classList.remove("visible"), seconds * 1000);
		},

		emoji(symbols, count) {
			for (let i = 0; i < count; i++) {
				setTimeout(() => {
					const start = headClient(random(-90, 90), random(-110, -40));
					const node = document.createElement("div");
					node.className = "float-emoji";
					node.textContent = symbols[Math.floor(Math.random() * symbols.length)];
					layer.appendChild(node);
					const drift = random(-40, 40);
					const tilt = random(-25, 25);
					node.animate(
						[
							{ transform: `translate(${start.x}px, ${start.y}px) scale(0.4)`, opacity: 0 },
							{ transform: `translate(${start.x}px, ${start.y - 20}px) scale(1.1)`, opacity: 1, offset: 0.15 },
							{ transform: `translate(${start.x + drift}px, ${start.y - 150}px) rotate(${tilt}deg) scale(1)`, opacity: 0 },
						],
						{ duration: 1400, easing: "ease-out" },
					).onfinish = () => node.remove();
				}, i * 110);
			}
		},

		burst(kind, count, at) {
			if (!PARTICLES[kind]) {
				return;
			}
			const origin = at ?? headClient(0, 40);
			for (let i = 0; i < count; i++) {
				particle(kind, origin.x + random(-10, 10), origin.y + random(-10, 10));
			}
		},

		play(name) {
			const emoji = EMOJI_EFFECTS[name];
			if (emoji) {
				this.emoji(emoji.symbols, emoji.count);
			} else if (name === "Confetti") {
				this.burst("Confetti", 70, headClient(0, -40));
				this.burst("Sparkles", 20);
			} else if (name === "Bubbles") {
				this.burst("Bubbles", 24);
				this.burst("Sparkles", 10);
			} else {
				this.burst(name, 18);
			}
		},

		setThought(icon) {
			if (icon) {
				thought.textContent = icon;
				thought.classList.add("visible");
				this.update();
			} else {
				thought.classList.remove("visible");
			}
		},

		setSleeping(on) {
			if (on && !sleepTimer) {
				sleepTimer = setInterval(() => this.emoji(["💤"], 1), 1600);
			} else if (!on && sleepTimer) {
				clearInterval(sleepTimer);
				sleepTimer = null;
			}
		},

		// A fly that buzzes around; the caller moves and removes it.
		spawnFly() {
			const node = document.createElement("div");
			node.className = "fly";
			layer.appendChild(node);
			let position = headClient(260, -180);
			place(node, position.x, position.y);
			return {
				position: () => position,
				moveTo(x, y, ms) {
					node.animate([{ transform: `translate(${position.x}px, ${position.y}px)` }, { transform: `translate(${x}px, ${y}px)` }], {
						duration: ms,
						easing: "ease-in-out",
						fill: "forwards",
					});
					position = { x, y };
				},
				remove() {
					node.remove();
				},
			};
		},
	};
}
