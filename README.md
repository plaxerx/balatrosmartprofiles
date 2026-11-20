# Smart Profiles

Designed with the modder in mind. Each of your Balatro profiles can now carry its own saved mod list and mod settings, and a new **V** profile plays pure vanilla (Multiplayer can come along at your discretion). No more turning off a pile of mods just to play the base game.

![The profile tabs: V, 1, 2 and 3](docs/profiles.png)

**Alpha.** Still being tested and constantly evolving.

## What it does

| Feature | Effect |
|---|---|
| **Vanilla profile (V)** | Every mod is locked off except Multiplayer and Smart Profiles. Achievements are back on under vanilla's own rules |
| **Saved mod lists** | Turn mods on and off in the Mods menu like normal, then hit **Save to profile**. That profile loads those mods from then on* |
| **Auto restart** | Load a profile and the game restarts with that profile's mods if they differ from what's running |
| **Mod settings per profile** | Each profile keeps its own mod settings, saved as you go |
| **New profiles** | Start with the mods of the last profile you used |
| **Profile badge** | The main menu shows which profile you're on |

*Changes you don't save stick around until you switch profiles

## Balatro Multiplayer

V is built with [Balatro Multiplayer](https://balatromp.com/download) in mind. Multiplayer stays on in V unless you turn it off there, and everything else is locked off so you show up to a lobby as vanilla. Smart Profiles adds no content of its own and shows in the lobby's mod list like any other mod.

## Required mods

- [Steamodded](https://github.com/Steamodded/smods) `>=1.0.0~BETA-0400` (tested on 26.1002.0)
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)

## Installation

Download this repository and place its contents in a folder inside your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/SmartProfiles/
```

Restart the game. The profile you're on saves its current mods the first time it loads.

## Uninstalling

Load one of your numbered profiles before removing this mod, otherwise the mods V turned off will stay off.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from [Claude](https://claude.ai).

Balatro is by LocalThunk. This mod is unofficial and not affiliated with the developer or publisher.
