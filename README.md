# Smart Profiles

Designed with the modder in mind. Each of your Balatro profiles now saves the mod lists and mod settings. A new **V** profile has been created for vanilla only runs (with multiplayer allowed at your discretion). No more turning off a pile of mods just to play the base game or forgetting which mod was in your curated list let alone how you configured it.

![The profile tabs: V, 1, 2 and 3](docs/profiles.png)

**Initial alpha release.** Still being tested and please submit any encountered bugs.

## What it does

| Feature | Effect |
|---|---|
| **Vanilla profile (V)** | New profile added where every mod is locked from use except Multiplayer and Smart Profiles. Achievements are back on under vanilla's own rules |
| **Saved mod lists** | Turn mods on and off in the Mods menu like normal, then hit **Save to profile**. That profile loads those mods from then on* |
| **Auto restart** | Load a profile and the game restarts with that profile's mods if they differ from what's running (required to reload mods) |
| **Mod settings per profile** | Each profile keeps its own mod settings as well |
| **Profile badge** | The main menu now shows which profile number you're on as well |

*Changes you don't save will remain until you switch profiles

## Balatro Multiplayer compliance and compatibility

V is built with [Balatro Multiplayer](https://balatromp.com/download) in mind. Multiplayer stays permitted in V where you can turn it on and off as desired. Everything else is locked off so you show up to a multiplayer lobby compliantly.

## Required mods

- [Steamodded](https://github.com/Steamodded/smods) `>=1.0.0~BETA-0400` (tested on 26.1002.0)
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)

## Installation

Download this repository and place its contents in a folder inside your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/SmartProfiles/
```

## Uninstalling

Load one of your numbered profiles prior to removing this mod.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from [Claude](https://claude.ai).

Balatro is by LocalThunk. This mod is unofficial and not affiliated with the developer or publisher.
