// Run with: node --test tests/
import { test } from "node:test";
import assert from "node:assert/strict";

import { matchPhrase, QuickPhrases } from "../js/config/talk.js";
import { advance, mood, happiness } from "../js/needs.js";
import { Reactions, Moods, Idle } from "../js/config/reactions.js";
import { Expressions } from "../js/plant/expressions.js";
import { Poses } from "../js/plant/poses.js";
import { Care } from "../js/config/plant.js";

const reaction = (text) => matchPhrase(text)?.reaction ?? null;
const fullPlant = () => ({ needs: { water: 100, nutrients: 100, energy: 100, cleanliness: 100 }, affection: 0, asleep: false, updatedAt: 0 });

test("phrases map to reactions", () => {
	assert.equal(reaction("HELLO!"), "Greet");
	assert.equal(reaction("I love you."), "Love");
	assert.equal(reaction("YOU'RE UGLY."), "Offended");
	assert.equal(reaction("You’re ugly"), "Offended");
	assert.equal(reaction("good night"), "Sleepy");
	assert.equal(reaction("How are you?"), "Status");
	assert.equal(reaction("Tell me a joke"), "Joke");
	assert.equal(reaction("Dance!"), "Dance");
	assert.equal(reaction("this is high"), null, "'high' must not match 'hi'");
	assert.equal(reaction("purple monkey"), null);
	for (const phrase of QuickPhrases) {
		assert.notEqual(reaction(phrase), null, `quick phrase "${phrase}" should be understood`);
	}
});

test("needs decay online and offline", () => {
	const plant = fullPlant();
	assert.ok(Math.abs(advance(plant, 600).needs.water - 90) < 1e-9, "10 min online: water 100 -> 90");
	assert.equal(plant.needs.water, 100, "advance must not mutate its input");
	assert.equal(advance(plant, 3 * 86400, true).needs.water, 15, "offline floors at 15");
	const low = { ...fullPlant(), needs: { ...fullPlant().needs, water: 5 } };
	assert.equal(advance(low, 99999, true).needs.water, 5, "offline floor never raises a need");
});

test("sleep refills energy", () => {
	const sleepy = { ...fullPlant(), needs: { ...fullPlant().needs, energy: 10 }, asleep: true };
	assert.ok(Math.abs(advance(sleepy, 600).needs.energy - 70) < 1e-9);
	assert.equal(mood(sleepy), "Sleeping");
});

test("mood follows needs and happiness", () => {
	assert.equal(mood(fullPlant()), "Happy");
	assert.equal(happiness(fullPlant()), 75);
	assert.equal(mood({ ...fullPlant(), needs: { ...fullPlant().needs, water: 5 } }), "Thirsty");
	assert.equal(mood({ ...fullPlant(), needs: { water: 40, nutrients: 40, energy: 40, cleanliness: 40 } }), "Sad");
});

test("every referenced preset exists", () => {
	for (const [id, def] of Object.entries(Reactions)) {
		if (def.expression) assert.ok(Expressions[def.expression], `${id}: expression ${def.expression}`);
		if (def.pose) assert.ok(Poses[def.pose], `${id}: pose ${def.pose}`);
	}
	for (const [name, def] of Object.entries(Moods)) {
		assert.ok(Expressions[def.expression], `mood ${name}`);
		assert.ok(Poses[def.pose], `mood ${name}`);
	}
	for (const entry of Idle) assert.ok(Reactions[entry.id], `idle ${entry.id}`);
	for (const def of Object.values(Care)) {
		assert.ok(Reactions[def.reaction]);
		assert.ok(Reactions[def.fullReaction]);
	}
	for (const id of ["Celebrate", "WelcomeBack", "WokenGrumpy", "SleepSmile", "Echo", "Busy", "Confused", "Status"]) {
		assert.ok(Reactions[id], id);
	}
});
