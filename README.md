# Gen1Recomp Minimal Cheats

Gen1Recomp Minimal Cheats is a lightweight, non-invasive single-player cheat menu mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). It integrates directly into the normal in-game Options menu and uses Gen1Recomp's public Mod API, hooks, and events wherever practical instead of replacing core game files.

## Features

Open `Options -> CHEATS` to access three categories.

### Battle

- Infinite HP: ON/OFF
- Infinite PP: ON/OFF
- EXP Multiplier: x1 / x2 / x4 / x8 / x10
- Damage Multiplier: x1 / x2 / x4 / x8 / x10 / OHKO
- Always Hit: ON/OFF
- Always Critical Hit: ON/OFF
- Always Move First: ON/OFF
- Always Escape: ON/OFF
- 100% Catch Rate: ON/OFF

### World

- No Wild Encounters: ON/OFF
- Movement Speed: x1 / x2 / x3 / x4

### Supplies

- Endless Poké Balls: ON/OFF
- PC Rare Candy: ON/OFF
  - Keeps at least 99 Rare Candies in the player's item-storage PC while enabled
  - Withdraw them, use them, or sell them, and the PC restocks them
  - Existing stacks above 99 are never reduced
  - The cheat will not delete another PC item if storage is already full
- Max Game Corner Coins
  - Sets the current coin count to 9999 when selected

## Online / PvP Safety

This mod is intended for single-player use. Battle-affecting cheats are explicitly disabled during online/link PvP and fall back to vanilla game behavior.

The implementation uses multiple safeguards: direct `battle.kind == "link"` checks where the hook provides a battle object, an active link-battle/session lock for hooks without one, and an additional link-only context check for turn-order handling.

The manifest keeps `affects_link` set to `false` because the mod is designed to be inert for link-battle gameplay.

## Runtime Behavior

Cheat settings are persistent and are read when their relevant hooks/events fire, so settings can be changed without restarting the game.

Existing v1.0.0 setting keys are preserved, so upgrading does not intentionally reset the original cheat choices.

## Installation

1. Open the GitHub Releases page.
2. Download `gen1recomp-minimal-cheats-vX.X.X.zip`.
3. Open Gen1Recomp.
4. Use Gen1Recomp's mod ZIP import/install function.
5. Enable the mod if required.
6. Open `Options -> CHEATS`.
7. Configure the desired cheats.

Do **not** use GitHub's automatic `Source code.zip` or `Source code.tar.gz` downloads as the installable mod. Download the specifically named release ZIP asset instead.

## Development

The repository is the editable source of truth. Edit the unzipped source files, especially `main.lua`, rather than editing a generated release ZIP.

Keep changes non-invasive where practical, prefer public Gen1Recomp Mod API hooks/events, preserve link/PvP safety, and test gameplay changes before publishing a release.

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Nintendo, The Pokémon Company, Game Freak, or the Gen1Recomp developers.

No ROM or Pokémon game assets are included.
