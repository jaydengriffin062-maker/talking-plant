# Talking Plant 🌱

A virtual pet for the web where your companion is a living, talking houseplant.
**The plant is the game:** every action gets a reaction.

It's a static site (plain HTML, CSS and JavaScript modules) with no build step and no dependencies.

## Deploy to Vercel

1. Push this repo to GitHub.
2. In Vercel, choose **Add New → Project** and import the repo.
3. Leave the defaults (Framework preset: **Other**; no build command; output directory: the repo root) and click **Deploy**.

Or from a terminal: `npx vercel` (preview) and `npx vercel --prod`.

The microphone feature needs HTTPS, which Vercel provides automatically.

## Run locally

```bash
npm start        # serves the folder at http://localhost:3000
npm test         # logic tests (Node 20+)
```

Any static server works (`python -m http.server`, etc.). Opening `index.html` directly from disk won't work, because browsers block JavaScript modules on `file://`.

## What's in it

- **Expressive plant** drawn in SVG, with eyelids, brows, six mouth shapes, blush, tears, sweat and dizzy eyes, and leaves used as body language.
- **Personality:** it blinks, looks around, sneezes pollen, catches and eats a fly, dances, nods off, falls into its pot, and stares at you.
- **Touch:**
  - Tap its head to poke it; it gets annoyed after 3 pokes and angry after 5.
  - Rub its head to pet it (hearts).
  - Wiggle a leaf to tickle it.
  - Drag a leaf outward to pull it, and it yells "OW!".
  - Tap the pot and it looks down. Shake the pot and it gets dizzy.
- **Care tools** follow your finger or mouse:
  - Watering can: the soil darkens.
  - Fertilizer.
  - Sponge: scrubs off dirt.
  - Sleep: the room goes dark and the plant is tucked under a blanket. It refuses if it isn't tired.
- **Talking:**
  - Quick phrases, or type anything; it repeats whatever it doesn't understand.
  - **Hold 🎤** to record yourself, and it repeats you in a squeaky voice. In Chrome and Edge it also understands spoken phrases like "I love you".
  - The plant speaks its lines aloud.
- **Needs:** water, nutrients, energy and cleanliness, plus happiness derived from them. While you're away, needs drain at a quarter speed and never drop below 15. The plant greets you when you come back.
- **Coins:** paid only when a need was actually low, so spamming the buttons earns nothing.
- **About one minute of tutorial:** meet the plant, water it, and get +100 coins.
- **Sound effects** are synthesized, so there are no audio files. 🔊 mutes everything.
- **Saving:** progress is kept in the browser (`localStorage`) and works offline after the first load.

## Code map

```
index.html            page + HUD markup
styles.css            all styling (mobile-first, safe-area aware)
vercel.json           static hosting headers (allows the microphone)
js/main.js            entry point
js/config/            tunable data: needs/rewards, reactions & idle antics, phrases
js/needs.js           pure needs/mood math
js/state.js           save/load (localStorage), schema versioning
js/actions.js         game rules: care, touch affection, talk, cooldowns, coins
js/commands.js        runs an action and shows the result on the plant
js/plant/             SVG rig, face, expression & pose presets, the plant "brain"
js/effects.js         speech/thought bubbles, emoji, particles, the fly
js/interaction.js     gestures + care tools
js/tools.js           tool artwork
js/ui.js              HUD wiring
js/voice.js           record & squeaky playback, speech recognition, text-to-speech
js/sfx.js             synthesized sound effects
js/tutorial.js        first-time flow
tests/                node:test logic tests
```

### Adding content

- **A reaction:** add it to `js/config/reactions.js` using existing expressions, poses and effects. Add new face or body presets in `js/plant/expressions.js` or `js/plant/poses.js` if needed.
- **An idle antic:** add it to `Idle` with a weight and optional mood multipliers. Add a function to `Motions` in `js/plant/controller.js` only if it needs scripted movement.
- **A phrase:** add patterns to `js/config/talk.js`.
- **A save-data change:** new fields go in `template()` in `js/state.js` and are filled in for old saves automatically. If an existing field changes shape, bump `SCHEMA_VERSION` and add a `MIGRATIONS` step.

## Roadmap

- **Progression:** XP, levels, visual growth stages, a shop, pots and accessories
- **Content:** minigames (Bug Catcher, Sun Catcher, Root Runner), room customization, evolutions, mutations, Plant Index, daily rewards
- **Polish:** more animation, sound and VFX
