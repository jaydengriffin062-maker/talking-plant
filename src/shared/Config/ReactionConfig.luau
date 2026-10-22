--!strict
-- Every way the plant can react. The server answers care/talk requests with a
-- reaction id from this table; the client plays it.
--
--   expression  face preset (client Plant/Expressions); nil keeps the current face
--   pose        body-language preset (client Plant/Poses); nil keeps the current pose
--   duration    seconds before the plant returns to its mood
--   say         random line for the speech bubble (the server may override it)
--   effect      Hearts | Sparkles | Anger | Stars | Notes | Confetti | Bubbles | Zzz
--   hop         strength of a little jump (0-1.5)
--   motion      scripted movement (client PlantController Motions)

export type Reaction = {
	expression: string?,
	pose: string?,
	duration: number,
	say: { string }?,
	effect: string?,
	hop: number?,
	motion: string?,
}

local ReactionConfig = {}

ReactionConfig.Reactions = {
	-- Talking
	Greet = {
		expression = "Excited",
		pose = "Excited",
		duration = 2.2,
		say = { "HELLO!!", "Hiiii!", "Oh! A human! Hi!" },
		effect = "Sparkles",
		hop = 1,
	},
	Love = {
		expression = "Love",
		pose = "Happy",
		duration = 2.6,
		say = { "I love you too!", "Aww, stop it, I'm blushing!", "You're my favorite human!" },
		effect = "Hearts",
		hop = 0.6,
	},
	Offended = {
		expression = "Offended",
		pose = "Angry",
		duration = 2.6,
		say = { "EXCUSE ME?!", "Rude!! I'm gorgeous!", "I'm photosynthesizing, not ugly!" },
		effect = "Anger",
	},
	Sleepy = {
		expression = "Yawn",
		pose = "Tired",
		duration = 2.6,
		say = { "*yaaawn* ...bedtime?", "Night night already?" },
		effect = "Zzz",
	},
	Status = { expression = "Neutral", pose = "Neutral", duration = 2.8 },
	Joke = {
		expression = "Laugh",
		pose = "Happy",
		duration = 3.4,
		say = {
			"Why did the plant go to therapy? Too many deep roots!",
			"I'm rooting for you!",
			"What's a plant's favorite drink? Root beer!",
			"I'd tell you a tree joke, but it's a bit wooden.",
		},
		effect = "Notes",
	},
	Echo = { expression = "Excited", pose = "Happy", duration = 2.4, hop = 0.4 },
	Confused = {
		expression = "Surprised",
		pose = "Neutral",
		duration = 1.8,
		say = { "Huh?", "Say what?", "...I'm just a plant." },
	},
	Busy = {
		expression = "Annoyed",
		pose = "Neutral",
		duration = 1.8,
		say = { "One at a time! I only have one mouth!" },
	},

	-- Touch
	Boop = { expression = "Surprised", pose = "Happy", duration = 1, say = { "Boop!", "Hehe!", "Oh!" }, hop = 0.5 },
	Annoyed = { expression = "Annoyed", pose = "Angry", duration = 1.6, say = { "Hey!", "Quit it!", "...seriously?" } },
	Angry = {
		expression = "Angry",
		pose = "Angry",
		duration = 2.2,
		say = { "STOP POKING ME!", "I WILL GROW THORNS!" },
		effect = "Anger",
	},
	Petted = { expression = "Content", pose = "Happy", duration = 1.6, effect = "Hearts" },
	Rubbed = { expression = "Happy", pose = "Happy", duration = 1.4, effect = "Hearts" },
	Laugh = {
		expression = "Laugh",
		pose = "Excited",
		duration = 1.8,
		say = { "HAHAHA!", "Hehehe STOP!", "Not the leaves! Haha!" },
	},
	Giggle = { expression = "Happy", pose = "Happy", duration = 1, say = { "Hehe!", "Tee-hee!" } },
	Ow = {
		expression = "Angry",
		pose = "Angry",
		duration = 2,
		say = { "OW!!", "That's attached!!", "HEY! I need that!" },
		effect = "Anger",
		hop = 0.4,
	},
	Dizzy = {
		expression = "Dizzy",
		pose = "Dizzy",
		duration = 2.6,
		say = { "Whoaaa...", "The room is spinning..." },
		effect = "Stars",
	},
	LookDown = { expression = "Surprised", pose = "Neutral", duration = 1.3, say = { "Hm?", "Who's there?" }, motion = "LookDown" },
	WokenGrumpy = {
		expression = "Grumpy",
		pose = "Tired",
		duration = 2.2,
		say = { "Mmph... I was sleeping!", "Five more minutes..." },
		effect = "Anger",
	},
	SleepSmile = { expression = "Sleeping", pose = "Sleeping", duration = 1.6, say = { "*happy snore*" }, effect = "Hearts" },

	-- Care
	Drink = {
		expression = "Content",
		pose = "Happy",
		duration = 2,
		say = { "Ahhh, refreshing!", "*glug glug glug*", "Mmm, wet!" },
		effect = "Sparkles",
		hop = 0.6,
	},
	NotThirsty = { expression = "Stare", pose = "Neutral", duration = 1.8, say = { "I'm already full! *blub*", "Any more and I'll be soup!" } },
	Eat = {
		expression = "Chomp",
		pose = "Excited",
		duration = 2,
		say = { "NOM NOM NOM!", "Mmm, crunchy nutrients!", "Delicious dirt!" },
		effect = "Sparkles",
		hop = 0.8,
	},
	NotHungry = { expression = "Stare", pose = "Neutral", duration = 1.8, say = { "I'm stuffed!", "No more, please..." } },
	Cleaned = {
		expression = "Excited",
		pose = "Happy",
		duration = 2,
		say = { "Squeaky clean!", "I feel so fresh!" },
		effect = "Bubbles",
		hop = 0.5,
	},
	AlreadyClean = { expression = "Stare", pose = "Neutral", duration = 1.8, say = { "I'm already spotless!" } },
	FallAsleep = { expression = "Yawn", pose = "Tired", duration = 1.8, say = { "*yaaawn* Good night..." } },
	NotSleepy = { expression = "Annoyed", pose = "Neutral", duration = 2, say = { "But I'm not even tired!", "Sleep? NOW? No way!" } },
	WakeUp = {
		expression = "Happy",
		pose = "Stretch",
		duration = 2,
		say = { "Good morning!!", "*streeetch* I'm awake!" },
		effect = "Sparkles",
		motion = "Stretch",
	},
	SleepTalk = { expression = "Sleeping", pose = "Sleeping", duration = 1.6, say = { "Zzz... five more minutes..." } },
	Celebrate = {
		expression = "Excited",
		pose = "Dance",
		duration = 3,
		say = { "WOOHOO! I feel BIGGER!", "Thank you!! I'm growing!" },
		effect = "Confetti",
		hop = 1.2,
		motion = "Stretch",
	},
	WelcomeBack = {
		expression = "Excited",
		pose = "Excited",
		duration = 2.6,
		say = { "YOU'RE BACK!!", "I missed you SO much!" },
		effect = "Hearts",
		hop = 1,
	},

	-- Idle personality
	LookAround = { duration = 3.2, motion = "LookAround" },
	StareAtCamera = { expression = "Stare", pose = "Neutral", duration = 2.6, say = { "...", "*stares*" }, motion = "Stare" },
	Stretch = { expression = "Content", pose = "Stretch", duration = 2, motion = "Stretch" },
	ShakeLeaves = { expression = "Happy", pose = "Excited", duration = 1.2 },
	Yawn = { expression = "Yawn", pose = "Tired", duration = 2, say = { "*yaaawn*" } },
	Sneeze = { duration = 2.2, motion = "Sneeze" },
	Dance = { expression = "Excited", pose = "Dance", duration = 3.5, say = { "Watch THIS!", "Leaf it to me!" }, effect = "Notes" },
	CatchFly = { duration = 4.6, motion = "CatchFly" },
	SillyFace = { expression = "Silly", pose = "Happy", duration = 1.6, say = { "Bleh!" } },
	FallInPot = { duration = 2.6, motion = "FallInPot" },
	NodOff = { duration = 3.6, motion = "NodOff" },
	Hum = { expression = "Content", pose = "Happy", duration = 2.6, say = { "La la la~", "Hmm hmm hmm~" }, effect = "Notes" },
} :: { [string]: Reaction }

-- Each mood's resting face and body language.
ReactionConfig.Moods = {
	Happy = { expression = "Happy", pose = "Happy" },
	Neutral = { expression = "Neutral", pose = "Neutral" },
	Sad = { expression = "Sad", pose = "Sad" },
	Thirsty = { expression = "Thirsty", pose = "Droopy" },
	Hungry = { expression = "Hungry", pose = "Droopy" },
	Tired = { expression = "Tired", pose = "Tired" },
	Dirty = { expression = "Sick", pose = "Droopy" },
	Sleeping = { expression = "Sleeping", pose = "Sleeping" },
} :: { [string]: { expression: string, pose: string } }

export type IdleEntry = { id: string, weight: number, moods: { [string]: number }? }

-- Random personality moments while the plant is left alone.
-- `moods` multiplies the weight in that mood (0 disables it).
ReactionConfig.Idle = {
	{ id = "LookAround", weight = 5 },
	{ id = "StareAtCamera", weight = 1.5 },
	{ id = "Stretch", weight = 2, moods = { Tired = 0 } },
	{ id = "ShakeLeaves", weight = 2, moods = { Happy = 2, Sad = 0 } },
	{ id = "Hum", weight = 2, moods = { Happy = 2, Sad = 0, Thirsty = 0 } },
	{ id = "Yawn", weight = 1, moods = { Tired = 5 } },
	{ id = "NodOff", weight = 0.4, moods = { Tired = 6 } },
	{ id = "Sneeze", weight = 1, moods = { Dirty = 4 } },
	{ id = "Dance", weight = 1, moods = { Happy = 3, Sad = 0, Tired = 0 } },
	{ id = "CatchFly", weight = 1, moods = { Hungry = 4 } },
	{ id = "SillyFace", weight = 1, moods = { Sad = 0 } },
	{ id = "FallInPot", weight = 0.6 },
} :: { IdleEntry }

ReactionConfig.IdleInterval = { min = 6, max = 12 }

-- Thought-bubble icon when a need is low.
ReactionConfig.NeedIcons = {
	water = "💧",
	nutrients = "🌱",
	energy = "⚡",
	cleanliness = "🧼",
} :: { [string]: string }

return ReactionConfig
