// Body-language presets. The rig eases between them every frame.
//
//   leafAngle            arm-leaf angle in degrees (+ up, - droop)
//   flutterAmp/Speed     leaf wiggle
//   swayAmp/Speed        whole-plant side sway (degrees)
//   bobAmp/Speed         bouncing (head heights, ~0.1 = small)
//   headPitch            + looks down
//   tremble              random jitter
//   wobble               circular head wobble, for dizziness (degrees)
//   sink                 0-1 how far the plant retracts into its pot

export const POSE_KEYS = [
	"leafAngle",
	"flutterAmp",
	"flutterSpeed",
	"swayAmp",
	"swaySpeed",
	"bobAmp",
	"bobSpeed",
	"headPitch",
	"tremble",
	"wobble",
	"sink",
];

const pose = (values) => Object.fromEntries(POSE_KEYS.map((key, index) => [key, values[index]]));

// prettier-ignore
export const Poses = {
	//                leaf flAmp flSpd sway swSpd bob   bobSpd pitch trem  wob sink
	Neutral:  pose([  12,   4,    2,    3,   1.1,  0,    0,     0,    0,    0,  0    ]),
	Happy:    pose([  35,   6,    4,    4,   1.6,  0.06, 5,    -3,    0,    0,  0    ]),
	Excited:  pose([  50,  16,   18,    4,   3,    0.12, 9,    -5,    0,    0,  0    ]),
	Sad:      pose([ -50,   1.5,  1,    2,   0.6,  0,    0,    14,    0,    0,  0    ]),
	Droopy:   pose([ -25,   2,    1.5,  3,   0.8,  0,    0,     7,    0,    0,  0.05 ]),
	Tired:    pose([ -35,   1,    0.8,  5,   0.5,  0,    0,    10,    0,    0,  0.1  ]),
	Angry:    pose([   5,   0,    0,    0.5, 0.5,  0,    0,     4,    0.04, 0,  0    ]),
	Sleeping: pose([ -75,   0.5,  0.5,  1.5, 0.4,  0,    0,    18,    0,    0,  0.55 ]),
	Dizzy:    pose([ -10,   3,    3,    2,   1,    0,    0,     0,    0,   10,  0    ]),
	Dance:    pose([  55,  10,    8,   14,   6,    0.15, 12,   -4,    0,    0,  0    ]),
	Stretch:  pose([  80,   2,    2,    1,   1,    0,    0,   -10,    0,    0,  0    ]),
	Scared:   pose([ -20,   2,   25,    0,   0,    0,    0,     6,    0.05, 0,  0.35 ]),
};
