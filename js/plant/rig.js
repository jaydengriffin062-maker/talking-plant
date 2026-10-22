// Builds the plant as SVG and poses it every frame from a handful of numbers.
// Coordinates are SVG viewBox units (400 x 600). The head group's origin is the
// head's center; the face is drawn on top of the head and slides with the gaze.

import { el, set, fmt } from "./svg.js";
import { clamp } from "../needs.js";

const SOIL = { x: 200, y: 376 };
const STEM_LENGTH = 64;
const HEAD = { rx: 100, ry: 86 };
const EYE = { x: 38, y: -10, rx: 21, ry: 27 };
// Upper lid travel: top = 1 brings the lid edge this far down the eye.
const LID_TRAVEL = 0.72;
// Animation distances (hop, stretch) are in "head units" scaled to pixels.
const UNIT = 40;

const COLORS = {
	outline: "#2d5528",
	skinStroke: "#4c9a3c",
	// Eyelids match the head's shading around the eyes.
	lid: "#8bd56c",
	leafStroke: "#3f8a37",
	vein: "#9fdc85",
	stem: "#5fa046",
	pupil: "#1e231e",
	mouth: "#5a232d",
	tongue: "#ff7890",
	blush: "#ff8ca0",
	sickBlush: "#a99fe0",
	drop: "#8ccdff",
	dirt: "#6e5032",
	soil: "#6b4630",
	soilWet: "#3c2619",
};

const LEAF_PATH = "M0 0 C 25 -34, 80 -36, 106 -4 C 80 22, 25 22, 0 0 Z";
const LEAF_VEIN = "M6 -2 Q 52 -10 98 -5";
const SPROUT_PATH = "M0 0 C -19 -14, -17 -42, 0 -54 C 17 -42, 19 -14, 0 0 Z";
const GRIN_PATH = "M -32 -6 Q 0 44 32 -6 Z";

function defs() {
	return el("defs", {}, [
		el("radialGradient", { id: "headGrad", cx: "0.38", cy: "0.3", r: "0.8" }, [
			el("stop", { offset: "0", "stop-color": "#b3ea92" }),
			el("stop", { offset: "0.55", "stop-color": "#7dcd5f" }),
			el("stop", { offset: "1", "stop-color": "#5aa844" }),
		]),
		el("linearGradient", { id: "leafGrad", x1: "0", y1: "0", x2: "1", y2: "0" }, [
			el("stop", { offset: "0", "stop-color": "#4c9f43" }),
			el("stop", { offset: "1", "stop-color": "#78cc5f" }),
		]),
		el("linearGradient", { id: "potGrad", x1: "0", y1: "0", x2: "1", y2: "0" }, [
			el("stop", { offset: "0", "stop-color": "#c4643f" }),
			el("stop", { offset: "0.4", "stop-color": "#e69064" }),
			el("stop", { offset: "1", "stop-color": "#b4573a" }),
		]),
		el("linearGradient", { id: "rimGrad", x1: "0", y1: "0", x2: "1", y2: "0" }, [
			el("stop", { offset: "0", "stop-color": "#b65a3a" }),
			el("stop", { offset: "0.4", "stop-color": "#d97d55" }),
			el("stop", { offset: "1", "stop-color": "#a44f33" }),
		]),
		el("pattern", { id: "blanketPattern", width: "28", height: "28", patternUnits: "userSpaceOnUse" }, [
			el("rect", { width: "28", height: "28", fill: "#86aef0" }),
			el("rect", { width: "14", height: "14", fill: "#a6c4f6" }),
			el("rect", { x: "14", y: "14", width: "14", height: "14", fill: "#a6c4f6" }),
		]),
		el("clipPath", { id: "eyeClipL" }, [el("ellipse", { cx: -EYE.x, cy: EYE.y, rx: EYE.rx, ry: EYE.ry })]),
		el("clipPath", { id: "eyeClipR" }, [el("ellipse", { cx: EYE.x, cy: EYE.y, rx: EYE.rx, ry: EYE.ry })]),
		el("clipPath", { id: "grinClip" }, [el("path", { d: GRIN_PATH })]),
		el("clipPath", { id: "openClip" }, [el("ellipse", { cx: 0, cy: 0, rx: 13, ry: 17 })]),
	]);
}

function buildTable() {
	return el("g", { class: "table" }, [
		el("ellipse", { cx: 200, cy: 594, rx: 62, ry: 9, fill: "rgba(0,0,0,0.12)" }),
		el("rect", { x: 186, y: 530, width: 28, height: 62, rx: 6, fill: "#8f5f3d" }),
		el("rect", { x: 66, y: 518, width: 268, height: 16, rx: 8, fill: "#8f5f3d" }),
		el("ellipse", { cx: 200, cy: 518, rx: 134, ry: 16, fill: "#b8845a" }),
		el("ellipse", { cx: 200, cy: 514, rx: 82, ry: 9, fill: "rgba(0,0,0,0.18)" }),
	]);
}

function buildEye(side) {
	const cx = side * EYE.x;
	const lidFill = el("rect", { x: cx - 45, y: -120, width: 90, height: 80, fill: COLORS.lid });
	const lash = el("line", { x1: cx - 45, x2: cx + 45, y1: -40, y2: -40, stroke: COLORS.outline, "stroke-width": 5 });
	const lid = el("g", {}, [lidFill, lash]);
	const pupilDot = el("circle", { cx: 0, cy: 0, r: 12, fill: COLORS.pupil });
	const pupil = el("g", {}, [pupilDot, el("circle", { cx: -4, cy: -5, r: 4.2, fill: "#fff" })]);
	const dizzy = el(
		"text",
		{
			x: 0,
			y: 0,
			"text-anchor": "middle",
			"dominant-baseline": "central",
			"font-size": 34,
			"font-weight": 700,
			fill: COLORS.pupil,
			display: "none",
		},
		[],
	);
	dizzy.textContent = "@";
	const dizzyGroup = el("g", {}, [dizzy]);
	const lower = el("ellipse", { cx, cy: 200, rx: EYE.rx * 1.5, ry: EYE.ry * 1.3, fill: COLORS.lid });
	const clipped = el("g", { "clip-path": `url(#${side < 0 ? "eyeClipL" : "eyeClipR"})` }, [
		el("ellipse", { cx, cy: EYE.y, rx: EYE.rx, ry: EYE.ry, fill: "#fff" }),
		pupil,
		dizzyGroup,
		lower,
		lid,
	]);
	const outline = el("ellipse", {
		cx,
		cy: EYE.y,
		rx: EYE.rx + 1,
		ry: EYE.ry + 1,
		fill: "none",
		stroke: COLORS.outline,
		"stroke-width": 4,
	});
	const brow = el("line", {
		x1: cx - 16,
		x2: cx + 16,
		y1: 0,
		y2: 0,
		stroke: COLORS.outline,
		"stroke-width": 7,
		"stroke-linecap": "round",
	});
	return {
		cx,
		// Screen-left eye mirrors angles so "angry" always tilts inward.
		mirror: side < 0 ? 1 : -1,
		group: el("g", {}, [clipped, outline, brow]),
		lid,
		lidFill,
		lash,
		pupil,
		pupilDot,
		dizzy,
		dizzyGroup,
		lower,
		outline,
		brow,
	};
}

function buildMouth() {
	const stroke = { fill: "none", stroke: COLORS.mouth, "stroke-width": 6, "stroke-linecap": "round", "stroke-linejoin": "round" };
	const shapes = {
		Smile: el("path", { d: "M -30 -4 Q 0 26 30 -4", ...stroke }),
		Frown: el("path", { d: "M -26 12 Q 0 -10 26 12", ...stroke }),
		Grin: el("g", {}, [
			el("path", { d: GRIN_PATH, fill: COLORS.mouth }),
			el("ellipse", { cx: 0, cy: 22, rx: 15, ry: 9, fill: COLORS.tongue, "clip-path": "url(#grinClip)" }),
			el("path", { d: GRIN_PATH, ...stroke, "stroke-width": 4 }),
		]),
		Open: el("g", {}, [
			el("ellipse", { cx: 0, cy: 0, rx: 13, ry: 17, fill: COLORS.mouth }),
			el("ellipse", { cx: 0, cy: 12, rx: 10, ry: 7, fill: COLORS.tongue, "clip-path": "url(#openClip)" }),
		]),
		Flat: el("line", { x1: -18, x2: 18, y1: 4, y2: 4, ...stroke }),
		Wavy: el("polyline", { points: "-27,2 -18,-5 -9,7 0,-5 9,7 18,-5 27,2", ...stroke, "stroke-width": 5 }),
	};
	const tongue = el("g", { display: "none" }, [
		el("ellipse", { cx: 10, cy: 16, rx: 9, ry: 13, fill: COLORS.tongue, stroke: "#d9506c", "stroke-width": 2 }),
		el("line", { x1: 10, x2: 10, y1: 8, y2: 22, stroke: "#d9506c", "stroke-width": 2 }),
	]);
	const group = el("g", {}, [...Object.values(shapes), tongue]);
	return { group, shapes, tongue };
}

function drop(x, y, size) {
	return el("path", {
		d: `M ${x} ${y - size} Q ${x + size * 0.8} ${y} ${x} ${y + size * 0.6} Q ${x - size * 0.8} ${y} ${x} ${y - size} Z`,
		fill: COLORS.drop,
		stroke: "#5aa8e0",
		"stroke-width": 2,
	});
}

export function buildRig(svg) {
	svg.setAttribute("viewBox", "0 0 400 600");
	svg.appendChild(defs());
	svg.appendChild(buildTable());

	const soil = el("ellipse", {
		cx: SOIL.x,
		cy: SOIL.y,
		rx: 88,
		ry: 13,
		fill: COLORS.soil,
		"data-zone": "soil",
		class: "soil",
	});
	svg.appendChild(soil);

	// Leaves (behind the head), sprouts, then the head with its face.
	const leaves = {};
	const sprouts = {};
	const leafLayer = el("g");
	for (const side of [1, -1]) {
		const leaf = el("g", { "data-zone": "leaf", "data-side": side }, [
			el("path", { d: LEAF_PATH, fill: "url(#leafGrad)", stroke: COLORS.leafStroke, "stroke-width": 3 }),
			el("path", { d: LEAF_VEIN, fill: "none", stroke: COLORS.vein, "stroke-width": 3, "stroke-linecap": "round" }),
		]);
		const sprout = el("g", { "data-zone": "leaf", "data-side": side }, [
			el("path", { d: SPROUT_PATH, fill: "url(#leafGrad)", stroke: COLORS.leafStroke, "stroke-width": 3 }),
		]);
		leaves[side] = leaf;
		sprouts[side] = sprout;
		leafLayer.append(leaf, sprout);
	}

	const dirtSpots = [
		[-62, -40, 13],
		[58, 52, 11],
		[20, -66, 10],
		[-40, 58, 14],
	].map(([x, y, r]) => el("ellipse", { cx: x, cy: y, rx: r, ry: r * 0.8, fill: COLORS.dirt, opacity: 0 }));

	const eyes = [buildEye(-1), buildEye(1)];
	const mouth = buildMouth();
	const blush = [-1, 1].map((side) => el("ellipse", { cx: side * 64, cy: 26, rx: 16, ry: 9, fill: COLORS.blush, opacity: 0 }));
	const tear = drop(-48, 30, 9);
	const sweat = drop(82, -58, 10);
	const anger = el("text", { x: 74, y: -60, "font-size": 34, "text-anchor": "middle", display: "none" });
	anger.textContent = "💢";
	const mouthGroup = el("g", {}, [mouth.group]);

	const face = el("g", { class: "face" }, [...blush, ...eyes.map((eye) => eye.group), mouthGroup, tear, sweat, anger]);
	const headBody = el("g", { "data-zone": "head" }, [
		el("ellipse", { cx: 0, cy: 0, rx: HEAD.rx, ry: HEAD.ry, fill: "url(#headGrad)", stroke: COLORS.skinStroke, "stroke-width": 4 }),
		el("ellipse", { cx: -42, cy: -46, rx: 22, ry: 12, fill: "#fff", opacity: 0.25, transform: "rotate(-25 -42 -46)" }),
		...dirtSpots,
		face,
	]);
	const head = el("g", {}, [leafLayer, headBody]);
	const stem = el("path", { d: "", fill: "none", stroke: COLORS.stem, "stroke-width": 16, "stroke-linecap": "round" });
	const plant = el("g", {}, [stem, head]);
	svg.appendChild(plant);

	// The pot is drawn after the plant so the plant can sink behind it.
	const potDirt = [
		[160, 452, 12],
		[240, 474, 10],
		[208, 428, 9],
	].map(([x, y, r]) => el("ellipse", { cx: x, cy: y, rx: r, ry: r * 0.75, fill: COLORS.dirt, opacity: 0 }));
	const pot = el("g", { "data-zone": "pot" }, [
		el("path", {
			d: "M112 388 L288 388 L270 500 Q268 512 256 512 L144 512 Q132 512 130 500 Z",
			fill: "url(#potGrad)",
			stroke: "#9c4f32",
			"stroke-width": 3,
		}),
		el("path", { d: "M121 430 L279 430", stroke: "#f2a57a", "stroke-width": 5, opacity: 0.6 }),
		...potDirt,
		el("rect", { x: 100, y: 370, width: 200, height: 30, rx: 12, fill: "url(#rimGrad)", stroke: "#9c4f32", "stroke-width": 3 }),
	]);
	svg.appendChild(pot);

	const blanket = el("g", { class: "blanket" }, [
		el("rect", { x: 90, y: 352, width: 220, height: 96, rx: 30, fill: "url(#blanketPattern)", stroke: "#5d86d6", "stroke-width": 4 }),
		el("path", { d: "M100 376 Q 200 396 300 376", fill: "none", stroke: "#fff", "stroke-width": 6, opacity: 0.7, "stroke-linecap": "round" }),
	]);
	svg.appendChild(blanket);

	let headY = SOIL.y - STEM_LENGTH - HEAD.ry;
	let headX = SOIL.x;

	function render({ pose, extras, face: f, t }) {
		const sway = pose.swayAmp * Math.sin(t * pose.swaySpeed);
		const roll = sway + pose.wobble * Math.sin(t * 7);
		const sink = clamp(pose.sink + extras.sinkAdd, 0, 1.4);
		const bob = pose.bobAmp * Math.abs(Math.sin(t * pose.bobSpeed));
		const stemLength = Math.max(4, STEM_LENGTH * (1 - Math.min(sink, 1)) + (extras.hop + bob + extras.stretch) * UNIT);
		headY = SOIL.y - stemLength - HEAD.ry * 0.84 + sink * HEAD.ry * 0.9 + extras.lean * 0.6;
		const jitter = pose.tremble > 0 ? (Math.random() - 0.5) * pose.tremble * UNIT : 0;
		headX = SOIL.x + jitter;
		const headRoll = pose.wobble * Math.cos(t * 7) * 0.6;
		const scale = 1 - extras.lean * 0.004;

		set(plant, { transform: `rotate(${fmt(roll)} ${SOIL.x} ${SOIL.y})` });
		set(stem, { d: `M ${SOIL.x} ${SOIL.y} L ${SOIL.x} ${fmt(headY + HEAD.ry * 0.6)}` });
		set(head, { transform: `translate(${fmt(headX)} ${fmt(headY)}) rotate(${fmt(headRoll)}) scale(${fmt(scale)})` });

		for (const side of [1, -1]) {
			const flutter = pose.flutterAmp * Math.sin(t * pose.flutterSpeed + (side === 1 ? 0 : 1.7));
			const angle = pose.leafAngle + flutter;
			const stretch = 1 + (extras.pull[side] ?? 0);
			const mirror = side === 1 ? "" : " scale(-1 1)";
			set(leaves[side], {
				transform: `translate(${side * 84} 16)${mirror} rotate(${fmt(-angle)}) scale(${fmt(stretch)} 1)`,
			});
			const tilt = clamp(28 - pose.leafAngle * 0.5 + flutter * 0.6, 5, 110);
			set(sprouts[side], { transform: `translate(${side * 8} -80) rotate(${fmt(side * tilt)})` });
		}

		// Face slides with the gaze for a cheap 3D head turn.
		const lookX = extras.lookYaw * 0.8;
		const lookY = (pose.headPitch + extras.lookPitch) * 0.55;
		set(face, { transform: `translate(${fmt(lookX)} ${fmt(lookY)})` });

		const topAmount = Math.max(f.top, f.blink);
		const closedness = clamp((topAmount - 0.8) / 0.15, 0, 1);
		const bottomAmount = Math.max(f.bottom, closedness * 0.3);
		const eyeTop = EYE.y - EYE.ry;
		const eyeHeight = EYE.ry * 2;
		const lidEdge = eyeTop + topAmount * LID_TRAVEL * eyeHeight;
		for (const eye of eyes) {
			set(eye.lid, { transform: `rotate(${fmt(eye.mirror * f.lidAngle)} ${eye.cx} ${fmt(lidEdge)})` });
			set(eye.lidFill, { y: fmt(lidEdge - 80) });
			set(eye.lash, { y1: fmt(lidEdge), y2: fmt(lidEdge) });
			set(eye.lower, { cy: fmt(EYE.y + EYE.ry - bottomAmount * eyeHeight + EYE.ry * 1.3) });
			set(eye.outline, { opacity: fmt(1 - closedness) });

			const pupilX = f.cross ? eye.mirror * 8 : f.look.x * 8;
			const pupilY = f.look.y * 8;
			set(eye.pupil, { transform: `translate(${fmt(eye.cx + pupilX)} ${fmt(EYE.y + 3 + pupilY)})` });
			set(eye.pupilDot, { r: fmt(22 * f.pupil) });
			set(eye.pupil, { display: f.dizzy ? "none" : "inline" });
			set(eye.dizzy, { display: f.dizzy ? "inline" : "none" });
			if (f.dizzy) {
				set(eye.dizzyGroup, { transform: `translate(${eye.cx} ${EYE.y}) rotate(${fmt((t * 400) % 360)})` });
			}

			const browY = eyeTop - 13 + f.browY * 200;
			set(eye.brow, {
				y1: fmt(browY),
				y2: fmt(browY),
				transform: `rotate(${fmt(eye.mirror * f.browAngle)} ${eye.cx} ${fmt(browY)})`,
			});
		}

		set(mouthGroup, { transform: `translate(0 46) scale(${fmt(f.mouthScale)})` });
		for (const [name, shape] of Object.entries(mouth.shapes)) {
			set(shape, { display: name === f.mouth ? "inline" : "none" });
		}
		set(mouth.tongue, { display: f.tongue ? "inline" : "none" });
		for (const cheek of blush) {
			set(cheek, { opacity: fmt(f.blush * 0.55), fill: f.sickly ? COLORS.sickBlush : COLORS.blush });
		}
		set(tear, { display: f.tear ? "inline" : "none" });
		set(sweat, { display: f.sweat ? "inline" : "none" });
		set(anger, { display: f.anger ? "inline" : "none" });
	}

	return {
		svg,
		render,
		headPoint: () => ({ x: headX, y: headY }),
		headRadius: HEAD.ry,
		pot,
		soilY: SOIL.y,

		// 0 = clean, 1 = filthy. Spots appear one by one.
		setDirt(amount) {
			const all = [...dirtSpots, ...potDirt];
			all.forEach((spot, index) => {
				const visible = clamp(amount * all.length - index, 0, 1);
				set(spot, { opacity: fmt(visible * 0.8) });
			});
		},
		setSleeping(asleep) {
			blanket.classList.toggle("visible", asleep);
		},
		setSoilWet(wet) {
			soil.style.fill = wet ? COLORS.soilWet : COLORS.soil;
		},
		toClient(x, y) {
			const matrix = svg.getScreenCTM();
			if (!matrix) {
				return { x: 0, y: 0 };
			}
			const point = new DOMPoint(x, y).matrixTransform(matrix);
			return { x: point.x, y: point.y };
		},
		toSvg(clientX, clientY) {
			const matrix = svg.getScreenCTM();
			if (!matrix) {
				return { x: 0, y: 0 };
			}
			const point = new DOMPoint(clientX, clientY).matrixTransform(matrix.inverse());
			return { x: point.x, y: point.y };
		},
		// Pixels per SVG unit on screen.
		scale() {
			return svg.getScreenCTM()?.a ?? 1;
		},
	};
}
