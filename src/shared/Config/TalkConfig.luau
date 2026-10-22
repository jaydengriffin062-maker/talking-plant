--!strict
-- What the plant understands. Phrases are matched as whole words/phrases on
-- lower-cased text with punctuation removed, in list order (first match wins).
-- Anything unmatched is echoed back (filtered) like a parrot.
--
-- This is the "talk input" layer: text today, but anything that can produce a
-- string (voice transcription later) can feed the same Talk remote.

local TalkConfig = {}

TalkConfig.MaxLength = 100

export type Phrase = { patterns: { string }, reaction: string, affection: number? }

TalkConfig.Phrases = {
	{ patterns = { "i love you", "love you", "ily", "you're cute", "you are cute", "good plant", "cute" }, reaction = "Love", affection = 6 },
	{ patterns = { "ugly", "stupid", "dumb", "hate you", "weed", "bad plant", "smelly", "stinky" }, reaction = "Offended", affection = -3 },
	{ patterns = { "good night", "goodnight", "nighty night", "bedtime", "go to sleep", "sleep" }, reaction = "Sleepy" },
	{ patterns = { "how are you", "you ok", "are you ok", "hungry", "thirsty", "how do you feel" }, reaction = "Status" },
	{ patterns = { "joke", "make me laugh", "say something funny" }, reaction = "Joke", affection = 2 },
	{ patterns = { "dance", "boogie" }, reaction = "Dance", affection = 2 },
	{ patterns = { "hello", "hi", "hey", "hiya", "yo", "sup", "hola", "good morning" }, reaction = "Greet", affection = 3 },
} :: { Phrase }

-- Quick chips in the talk panel; always available, even when free text is not.
TalkConfig.QuickPhrases = { "Hello!", "I love you", "How are you?", "Tell me a joke", "Dance!", "You're ugly", "Good night" }

-- Lines for the Status reaction, picked by the plant's lowest need.
TalkConfig.StatusLines = {
	water = "My roots are SO thirsty...",
	nutrients = "I could really go for some fertilizer...",
	energy = "I'm sooo sleepy...",
	cleanliness = "I feel kinda... crusty.",
	fine = "I feel GREAT! Very photosynthetic!",
} :: { [string]: string }

local function normalize(text: string): string
	local lowered = string.lower(text)
	lowered = string.gsub(lowered, "[^%w%s']", " ")
	lowered = string.gsub(lowered, "%s+", " ")
	return " " .. lowered .. " "
end

function TalkConfig.match(text: string): Phrase?
	local normalized = normalize(text)
	for _, phrase in TalkConfig.Phrases do
		for _, pattern in phrase.patterns do
			if string.find(normalized, " " .. pattern .. " ", 1, true) then
				return phrase
			end
		end
	end
	return nil
end

return TalkConfig
