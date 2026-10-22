// Every way the plant can react.
//
//   expression  face preset (plant/expressions.js); omitted keeps the current face
//   pose        body-language preset (plant/poses.js); omitted keeps the current pose
//   duration    seconds before the plant returns to its mood
//   say         random line for the speech bubble (callers may override it)
//   effect      Hearts | Sparkles | Anger | Stars | Notes | Confetti | Bubbles | Zzz | Pollen
//   hop         strength of a little jump (0-1.5)
//   motion      scripted movement (plant/controller.js Motions)
//   sfx         sound effect (sfx.js)

export const Reactions = {
	// Talking
	Greet: {
		expression: "Excited",
		pose: "Excited",
		duration: 2.2,
		say: ["HELLO!!", "Hiiii!", "Oh! A human! Hi!"],
		effect: "Sparkles",
		hop: 1,
		sfx: "happy",
	},
	Love: {
		expression: "Love",
		pose: "Happy",
		duration: 2.6,
		say: ["I love you too!", "Aww, stop it, I'm blushing!", "You're my favorite human!"],
		effect: "Hearts",
		hop: 0.6,
		sfx: "happy",
	},
	Offended: {
		expression: "Offended",
		pose: "Angry",
		duration: 2.6,
		say: ["EXCUSE ME?!", "Rude!! I'm gorgeous!", "I'm photosynthesizing, not ugly!"],
		effect: "Anger",
		sfx: "angry",
	},
	Sleepy: {
		expression: "Yawn",
		pose: "Tired",
		duration: 2.6,
		say: ["*yaaawn* ...bedtime?", "Night night already?"],
		effect: "Zzz",
		sfx: "snore",
	},
	Status: { expression: "Neutral", pose: "Neutral", duration: 2.8 },
	Joke: {
		expression: "Laugh",
		pose: "Happy",
		duration: 3.4,
		say: [
			"Why did the plant go to therapy? Too many deep roots!",
			"I'm rooting for you!",
			"What's a plant's favorite drink? Root beer!",
			"I'd tell you a tree joke, but it's a bit wooden.",
		],
		effect: "Notes",
		sfx: "laugh",
	},
	Echo: { expression: "Excited", pose: "Happy", duration: 2.4, hop: 0.4 },
	Confused: {
		expression: "Surprised",
		pose: "Neutral",
		duration: 1.8,
		say: ["Huh?", "Say what?", "...I'm just a plant."],
		sfx: "boop",
	},
	Busy: {
		expression: "Annoyed",
		pose: "Neutral",
		duration: 1.8,
		say: ["One at a time! I only have one mouth!"],
	},

	// Touch
	Boop: { expression: "Surprised", pose: "Happy", duration: 1, say: ["Boop!", "Hehe!", "Oh!"], hop: 0.5, sfx: "boop" },
	Annoyed: { expression: "Annoyed", pose: "Angry", duration: 1.6, say: ["Hey!", "Quit it!", "...seriously?"], sfx: "grumble" },
	Angry: {
		expression: "Angry",
		pose: "Angry",
		duration: 2.2,
		say: ["STOP POKING ME!", "I WILL GROW THORNS!"],
		effect: "Anger",
		sfx: "angry",
	},
	Petted: { expression: "Content", pose: "Happy", duration: 1.6, effect: "Hearts", sfx: "purr" },
	Rubbed: { expression: "Happy", pose: "Happy", duration: 1.4, effect: "Hearts", sfx: "purr" },
	Laugh: {
		expression: "Laugh",
		pose: "Excited",
		duration: 1.8,
		say: ["HAHAHA!", "Hehehe STOP!", "Not the leaves! Haha!"],
		sfx: "laugh",
	},
	Ow: {
		expression: "Angry",
		pose: "Angry",
		duration: 2,
		say: ["OW!!", "That's attached!!", "HEY! I need that!"],
		effect: "Anger",
		hop: 0.4,
		sfx: "angry",
	},
	Dizzy: {
		expression: "Dizzy",
		pose: "Dizzy",
		duration: 2.6,
		say: ["Whoaaa...", "The room is spinning..."],
		effect: "Stars",
		sfx: "dizzy",
	},
	LookDown: { expression: "Surprised", pose: "Neutral", duration: 1.3, say: ["Hm?", "Who's there?"], motion: "LookDown", sfx: "knock" },
	WokenGrumpy: {
		expression: "Grumpy",
		pose: "Tired",
		duration: 2.2,
		say: ["Mmph... I was sleeping!", "Five more minutes..."],
		effect: "Anger",
		sfx: "grumble",
	},
	SleepSmile: { expression: "Sleeping", pose: "Sleeping", duration: 1.6, say: ["*happy snore*"], effect: "Hearts", sfx: "snore" },

	// Care
	Drink: {
		expression: "Content",
		pose: "Happy",
		duration: 2,
		say: ["Ahhh, refreshing!", "*glug glug glug*", "Mmm, wet!"],
		effect: "Sparkles",
		hop: 0.6,
		sfx: "gulp",
	},
	NotThirsty: { expression: "Stare", pose: "Neutral", duration: 1.8, say: ["I'm already full! *blub*", "Any more and I'll be soup!"] },
	Eat: {
		expression: "Chomp",
		pose: "Excited",
		duration: 2,
		say: ["NOM NOM NOM!", "Mmm, crunchy nutrients!", "Delicious dirt!"],
		effect: "Sparkles",
		hop: 0.8,
		sfx: "munch",
	},
	NotHungry: { expression: "Stare", pose: "Neutral", duration: 1.8, say: ["I'm stuffed!", "No more, please..."] },
	Cleaned: {
		expression: "Excited",
		pose: "Happy",
		duration: 2,
		say: ["Squeaky clean!", "I feel so fresh!"],
		effect: "Bubbles",
		hop: 0.5,
		sfx: "sparkle",
	},
	AlreadyClean: { expression: "Stare", pose: "Neutral", duration: 1.8, say: ["I'm already spotless!"] },
	FallAsleep: { expression: "Yawn", pose: "Tired", duration: 1.8, say: ["*yaaawn* Good night..."], sfx: "snore" },
	NotSleepy: { expression: "Annoyed", pose: "Neutral", duration: 2, say: ["But I'm not even tired!", "Sleep? NOW? No way!"], sfx: "grumble" },
	WakeUp: {
		expression: "Happy",
		pose: "Stretch",
		duration: 2,
		say: ["Good morning!!", "*streeetch* I'm awake!"],
		effect: "Sparkles",
		motion: "Stretch",
		sfx: "happy",
	},
	SleepTalk: { expression: "Sleeping", pose: "Sleeping", duration: 1.6, say: ["Zzz... five more minutes..."], sfx: "snore" },
	Celebrate: {
		expression: "Excited",
		pose: "Dance",
		duration: 3,
		say: ["WOOHOO! I feel BIGGER!", "Thank you!! I'm growing!"],
		effect: "Confetti",
		hop: 1.2,
		motion: "Stretch",
		sfx: "fanfare",
	},
	WelcomeBack: {
		expression: "Excited",
		pose: "Excited",
		duration: 2.6,
		say: ["YOU'RE BACK!!", "I missed you SO much!"],
		effect: "Hearts",
		hop: 1,
		sfx: "happy",
	},

	// Idle personality
	LookAround: { duration: 3.2, motion: "LookAround" },
	StareAtCamera: { expression: "Stare", pose: "Neutral", duration: 2.6, say: ["...", "*stares*"], motion: "Stare" },
	Stretch: { expression: "Content", pose: "Stretch", duration: 2, motion: "Stretch" },
	ShakeLeaves: { expression: "Happy", pose: "Excited", duration: 1.2, sfx: "rustle" },
	Yawn: { expression: "Yawn", pose: "Tired", duration: 2, say: ["*yaaawn*"], sfx: "snore" },
	Sneeze: { duration: 2.2, motion: "Sneeze" },
	Dance: { expression: "Excited", pose: "Dance", duration: 3.5, say: ["Watch THIS!", "Leaf it to me!"], effect: "Notes", sfx: "tune" },
	CatchFly: { duration: 4.6, motion: "CatchFly" },
	SillyFace: { expression: "Silly", pose: "Happy", duration: 1.6, say: ["Bleh!"], sfx: "boop" },
	FallInPot: { duration: 2.6, motion: "FallInPot" },
	NodOff: { duration: 3.6, motion: "NodOff" },
	Hum: { expression: "Content", pose: "Happy", duration: 2.6, say: ["La la la~", "Hmm hmm hmm~"], effect: "Notes", sfx: "tune" },
};

// Each mood's resting face and body language.
export const Moods = {
	Happy: { expression: "Happy", pose: "Happy" },
	Neutral: { expression: "Neutral", pose: "Neutral" },
	Sad: { expression: "Sad", pose: "Sad" },
	Thirsty: { expression: "Thirsty", pose: "Droopy" },
	Hungry: { expression: "Hungry", pose: "Droopy" },
	Tired: { expression: "Tired", pose: "Tired" },
	Dirty: { expression: "Sick", pose: "Droopy" },
	Sleeping: { expression: "Sleeping", pose: "Sleeping" },
};

// Random personality moments while the plant is left alone.
// `moods` multiplies the weight in that mood (0 disables it).
export const Idle = [
	{ id: "LookAround", weight: 5 },
	{ id: "StareAtCamera", weight: 1.5 },
	{ id: "Stretch", weight: 2, moods: { Tired: 0 } },
	{ id: "ShakeLeaves", weight: 2, moods: { Happy: 2, Sad: 0 } },
	{ id: "Hum", weight: 2, moods: { Happy: 2, Sad: 0, Thirsty: 0 } },
	{ id: "Yawn", weight: 1, moods: { Tired: 5 } },
	{ id: "NodOff", weight: 0.4, moods: { Tired: 6 } },
	{ id: "Sneeze", weight: 1, moods: { Dirty: 4 } },
	{ id: "Dance", weight: 1, moods: { Happy: 3, Sad: 0, Tired: 0 } },
	{ id: "CatchFly", weight: 1, moods: { Hungry: 4 } },
	{ id: "SillyFace", weight: 1, moods: { Sad: 0 } },
	{ id: "FallInPot", weight: 0.6 },
];

export const idleInterval = { min: 6, max: 12 };

// Thought-bubble icon when a need is low.
export const NeedIcons = {
	water: "💧",
	nutrients: "🌱",
	energy: "⚡",
	cleanliness: "🧼",
};
