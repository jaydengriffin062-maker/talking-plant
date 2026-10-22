--!strict
-- Face presets. Values are fractions of the eye/face so they scale with the plant.
--
--   top / bottom   how far the upper / lower eyelid covers the eye (0-1)
--   lidAngle       upper lid tilt in degrees; + = angry (inner corners down), - = sad
--   pupil          pupil size relative to the eye
--   browY          eyebrow height offset; negative = raised
--   browAngle      eyebrow tilt; + = angry, - = worried
--   mouth          Smile | Grin | Frown | Open | Flat | Wavy
--   mouthScale     mouth size multiplier
--   flags          blush, tear, sweat, anger, dizzy, tongue, cross (cross-eyed), sickly

export type Expression = {
	top: number,
	bottom: number,
	lidAngle: number,
	pupil: number,
	browY: number,
	browAngle: number,
	mouth: string,
	mouthScale: number,
	blush: boolean?,
	tear: boolean?,
	sweat: boolean?,
	anger: boolean?,
	dizzy: boolean?,
	tongue: boolean?,
	cross: boolean?,
	sickly: boolean?,
}

local function expr(values: { [string]: any }): Expression
	local result: { [string]: any } = {
		top = 0.12,
		bottom = 0,
		lidAngle = 0,
		pupil = 0.55,
		browY = 0,
		browAngle = 0,
		mouth = "Smile",
		mouthScale = 0.8,
	}
	for key, value in values do
		result[key] = value
	end
	return result :: Expression
end

local Expressions: { [string]: Expression } = {
	Neutral = expr({}),
	Happy = expr({ top = 0.05, bottom = 0.3, browY = -0.02, browAngle = -8, mouth = "Grin", mouthScale = 0.9, blush = true }),
	Excited = expr({ top = 0, pupil = 0.62, browY = -0.06, browAngle = -12, mouth = "Grin", mouthScale = 1.1, blush = true }),
	Love = expr({ top = 0.05, bottom = 0.55, browY = -0.03, browAngle = -10, mouth = "Smile", mouthScale = 0.9, blush = true }),
	Content = expr({ top = 0.5, bottom = 0.45, browY = -0.02, browAngle = -6, mouth = "Smile", mouthScale = 0.85, blush = true }),
	Laugh = expr({ top = 0.1, bottom = 0.62, browY = -0.06, browAngle = -10, mouth = "Grin", mouthScale = 1.2, blush = true }),
	Sad = expr({ top = 0.3, lidAngle = -18, pupil = 0.6, browAngle = -20, mouth = "Frown", mouthScale = 0.7, tear = true }),
	Angry = expr({ top = 0.35, lidAngle = 22, pupil = 0.45, browY = 0.04, browAngle = 25, mouth = "Frown", mouthScale = 0.8, anger = true }),
	Offended = expr({ top = 0.25, lidAngle = 15, pupil = 0.4, browY = 0.02, browAngle = 20, mouth = "Open", mouthScale = 0.7, anger = true }),
	Annoyed = expr({ top = 0.45, lidAngle = 8, browY = 0.03, browAngle = 12, mouth = "Flat", mouthScale = 0.7 }),
	Grumpy = expr({ top = 0.55, lidAngle = 10, browY = 0.03, browAngle = 15, mouth = "Frown", mouthScale = 0.6, anger = true }),
	Tired = expr({ top = 0.58, lidAngle = -6, browY = 0.02, browAngle = -6, mouth = "Flat", mouthScale = 0.6 }),
	Sleeping = expr({ top = 1, browY = 0.03, browAngle = -4, mouth = "Open", mouthScale = 0.35 }),
	Yawn = expr({ top = 0.85, bottom = 0.2, browY = -0.04, browAngle = -10, mouth = "Open", mouthScale = 1.4 }),
	Hungry = expr({ top = 0.2, pupil = 0.65, browAngle = -14, mouth = "Open", mouthScale = 0.6, sweat = true }),
	Thirsty = expr({ top = 0.35, browAngle = -12, mouth = "Open", mouthScale = 0.6, tongue = true, sweat = true }),
	Surprised = expr({ top = 0, pupil = 0.4, browY = -0.08, browAngle = -6, mouth = "Open", mouthScale = 0.8 }),
	Sick = expr({ top = 0.4, pupil = 0.45, browAngle = -12, mouth = "Wavy", mouthScale = 0.8, sweat = true, sickly = true }),
	Dizzy = expr({ top = 0, dizzy = true, mouth = "Wavy", mouthScale = 0.9 }),
	Silly = expr({ top = 0, pupil = 0.62, browY = -0.04, mouth = "Smile", mouthScale = 0.9, tongue = true, cross = true }),
	Stare = expr({ top = 0.3, bottom = 0.15, pupil = 0.35, mouth = "Flat", mouthScale = 0.5 }),
	Chomp = expr({ top = 0.1, browAngle = 10, mouth = "Open", mouthScale = 1.3 }),
}

return Expressions
