// What the plant understands. Phrases are matched as whole words/phrases on
// lower-cased text with punctuation removed, in list order (first match wins).
// Anything unmatched is repeated back like a parrot.

export const maxLength = 100;

export const Phrases = [
	{ patterns: ["i love you", "love you", "ily", "you're cute", "you are cute", "good plant", "cute"], reaction: "Love", affection: 6 },
	{ patterns: ["ugly", "stupid", "dumb", "hate you", "weed", "bad plant", "smelly", "stinky"], reaction: "Offended", affection: -3 },
	{ patterns: ["good night", "goodnight", "nighty night", "bedtime", "go to sleep", "sleep"], reaction: "Sleepy" },
	{ patterns: ["how are you", "you ok", "are you ok", "hungry", "thirsty", "how do you feel"], reaction: "Status" },
	{ patterns: ["joke", "make me laugh", "say something funny"], reaction: "Joke", affection: 2 },
	{ patterns: ["dance", "boogie"], reaction: "Dance", affection: 2 },
	{ patterns: ["hello", "hi", "hey", "hiya", "yo", "sup", "hola", "good morning"], reaction: "Greet", affection: 3 },
];

// Quick chips in the talk panel.
export const QuickPhrases = ["Hello!", "I love you", "How are you?", "Tell me a joke", "Dance!", "You're ugly", "Good night"];

// Lines for the Status reaction, picked by the plant's lowest need.
export const StatusLines = {
	water: "My roots are SO thirsty...",
	nutrients: "I could really go for some fertilizer...",
	energy: "I'm sooo sleepy...",
	cleanliness: "I feel kinda... crusty.",
	fine: "I feel GREAT! Very photosynthetic!",
};

function normalize(text) {
	const lowered = text
		.toLowerCase()
		.replace(/[’‘]/g, "'")
		.replace(/[^\p{L}\p{N}\s']/gu, " ")
		.replace(/\s+/g, " ");
	return ` ${lowered.trim()} `;
}

export function matchPhrase(text) {
	const normalized = normalize(text);
	for (const phrase of Phrases) {
		for (const pattern of phrase.patterns) {
			if (normalized.includes(` ${pattern} `)) {
				return phrase;
			}
		}
	}
	return null;
}
