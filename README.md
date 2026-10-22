# Talking Plant

A Roblox virtual-pet game where your companion is a living, talking houseplant.
**The plant is the game:** every action gets a character reaction.

## Status: Phase 1 (core prototype)

- Expressive plant built from simple parts: face with eyes, eyelids, brows, mouth shapes, blush, tears and sweat; leaves used as body language
- Idle personality: blinking, looking around, sneezing, catching a fly, dancing, nodding off, falling into its pot, and more
- Touch gestures: poke (repeated pokes make it annoyed, then angry), pet, rub leaves, tickle, pull a leaf, tap the pot, shake
- Care tools that follow the pointer: watering can, fertilizer and sponge; a sleep/wake toggle that dims the room and tucks the plant in
- Talking: quick-phrase chips plus free text (server-filtered); unknown phrases are repeated back
- Needs (water, nutrients, energy, cleanliness, plus derived happiness), predicted on the client and authoritative on the server
- Save system with session locking, retries, autosave and shutdown flush
- About one minute of first-time tutorial: meet the plant, water it, earn +100 coins

The Games, Shop and Style tabs show "coming soon" until Phase 2 and 3.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs Rojo, Selene and StyLua).
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate in Studio, and connect from the Rojo plugin.
   (Or run `rojo build -o TalkingPlant.rbxl` and open the file.)
4. Delete the default Baseplate/SpawnLocation if present; the game builds its own room.
5. To test saving in Studio: publish the place and enable **Game Settings → Security → Enable Studio Access to API Services**.
   Without this, Studio uses a temporary unsaved profile and prints a warning.

## Architecture

There is exactly one server `Script` and one client `LocalScript`. Each boots its modules in a fixed order: every `init()` runs first, then every `start()`.

```
src/shared/                 ReplicatedStorage.Shared
  Config/PlantConfig        needs rates, care amounts, cooldowns, rewards
  Config/ReactionConfig     every reaction, mood presets, idle antics (data only)
  Config/TalkConfig         phrases the plant understands, quick chips
  Util/NeedsMath            pure needs/mood math, shared by client & server
  Net, Remotes, Types       the remote list, its access layer, shared types

src/server/                 ServerScriptService.Server
  Systems/DataService       profiles: UpdateAsync, session lock, autosave, migrations
  Systems/PlantService      validates & applies care/talk/touch; owns coins
  Util/RateLimiter          per-player token buckets for every remote

src/client/                 StarterPlayerScripts.Client
  Controllers/StateController       server snapshot + local prediction
  Controllers/RoomBuilder           the room and its day/night lighting
  Controllers/PlantController       mood → face/pose, reactions, motions, idle loop
  Controllers/Plant/*               rig, face, effects, expression & pose presets
  Controllers/InteractionController gestures and care tools
  Controllers/ActionController      care/talk requests → plant reaction
  Controllers/UIController + UI/*   HUD, needs panel, care tray, talk panel
  Controllers/TutorialController    first-time flow
```

### Adding content

- **A new reaction:** add an entry to `ReactionConfig.Reactions` that uses existing expressions, poses and effects. Add a face or body preset in `Plant/Expressions` or `Plant/Poses` if needed.
- **A new idle antic:** add it to `ReactionConfig.Idle` with a weight and optional mood multipliers. Add a function to `Motions` in `PlantController` only if it needs scripted movement.
- **A new phrase:** add patterns to `TalkConfig.Phrases`.
- **A new remote:** add its name to `Remotes.luau`. Then validate and rate-limit it in its server system.
- **A save-data change:** new fields go in `server/Data/ProfileTemplate` and are filled in automatically. If an existing field changes shape, bump `SCHEMA_VERSION` and add a `MIGRATIONS` step in `DataService`.

### Security model

The client only asks for things. The server checks every remote argument's type, rate-limits each player, enforces cooldowns, and pays coins only when a need was actually low. Repeated requests earn nothing. Free text is checked against `TextChatService:CanUserChatAsync` and passed through `TextService` filtering before the plant repeats it.

## Roadmap

- **Phase 2, progression:** XP, levels, visual growth stages, coins sink, shop, pots, accessories (standard attachment points)
- **Phase 3, content:** minigames (Bug Catcher, Sun Catcher, Root Runner), room customization, evolutions, mutations, Plant Index, daily rewards
- **Phase 4, polish:** sound, VFX, animation, mobile tuning, performance and exploit testing
