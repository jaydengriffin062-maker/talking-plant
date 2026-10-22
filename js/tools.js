// Care tool artwork. `tip` is the pixel in the artwork that sits over the
// pointer (spout, bag opening); `useTilt` is the pour rotation in degrees.

export const TOOLS = {
	Water: {
		width: 120,
		height: 92,
		tip: { x: 10, y: 24 },
		useTilt: -38,
		particle: "Water",
		sound: "splash",
		hint: "Hold the watering can over the pot 💧",
		svg: `
			<svg viewBox="0 0 120 92" width="120" height="92" aria-hidden="true">
				<path d="M44 58 L12 26" stroke="#3f8fd6" stroke-width="11" stroke-linecap="round"/>
				<path d="M44 58 L12 26" stroke="#5aaaf0" stroke-width="6" stroke-linecap="round"/>
				<ellipse cx="10" cy="24" rx="9" ry="7" fill="#3f8fd6" transform="rotate(-45 10 24)"/>
				<path d="M88 34 C 116 30, 118 70, 98 74" fill="none" stroke="#3f8fd6" stroke-width="8" stroke-linecap="round"/>
				<rect x="40" y="30" width="60" height="58" rx="12" fill="#5aaaf0" stroke="#3f8fd6" stroke-width="4"/>
				<rect x="44" y="26" width="52" height="10" rx="5" fill="#3f8fd6"/>
				<path d="M52 50 C 60 46, 70 46, 78 50" stroke="#a9d6ff" stroke-width="5" fill="none" stroke-linecap="round"/>
			</svg>`,
	},
	Feed: {
		width: 92,
		height: 112,
		tip: { x: 16, y: 18 },
		useTilt: -58,
		particle: "Soil",
		sound: "sprinkle",
		hint: "Hold the fertilizer over the pot 🌱",
		svg: `
			<svg viewBox="0 0 92 112" width="92" height="112" aria-hidden="true">
				<path d="M14 18 L78 14 L86 104 Q86 110 80 110 L12 110 Q6 110 6 104 Z" fill="#d9b07a" stroke="#a87b48" stroke-width="4" stroke-linejoin="round"/>
				<path d="M14 18 L78 14 L80 32 L12 34 Z" fill="#79c25c" stroke="#4f9a3c" stroke-width="3" stroke-linejoin="round"/>
				<circle cx="46" cy="68" r="22" fill="#fff6e0"/>
				<text x="46" y="70" text-anchor="middle" dominant-baseline="central" font-size="26">🌱</text>
			</svg>`,
	},
	Clean: {
		width: 96,
		height: 66,
		tip: { x: 48, y: 33 },
		useTilt: 0,
		particle: "Bubbles",
		sound: "scrub",
		hint: "Scrub your plant with the sponge 🧽",
		svg: `
			<svg viewBox="0 0 96 66" width="96" height="66" aria-hidden="true">
				<rect x="4" y="18" width="88" height="44" rx="12" fill="#ffd95a" stroke="#d9a92a" stroke-width="4"/>
				<rect x="4" y="6" width="88" height="18" rx="8" fill="#5fb85a" stroke="#3f8a3a" stroke-width="4"/>
				<circle cx="24" cy="40" r="4" fill="#e5b93a"/><circle cx="48" cy="48" r="5" fill="#e5b93a"/>
				<circle cx="70" cy="36" r="4" fill="#e5b93a"/><circle cx="36" cy="54" r="3" fill="#e5b93a"/>
			</svg>`,
	},
};
