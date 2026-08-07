# Gen1Recomp Minimal Cheats

Gen1Recomp Minimal Cheats is a lightweight, non-invasive cheat menu mod for Gen1Recomp that integrates into the normal in-game Options menu.

It is intentionally built around Gen1Recomp's public Mod API and documented hooks/events wherever possible instead of replacing core game files.

## v1.0.0 Features

- Infinite HP: ON/OFF
- Infinite PP: ON/OFF
- EXP Multiplier: x1 / x2 / x4 / x8 / x10
- Endless Poké Balls: ON/OFF
- 100% Catch Rate: ON/OFF
- Options -> CHEATS menu
- Runtime toggling without restarting
- Persistent settings
- Link Battle safeguards

## Installation

1. Open the GitHub Releases page.
2. Download `gen1recomp-minimal-cheats-vX.X.X.zip`.
3. Open Gen1Recomp.
4. Use Gen1Recomp's mod ZIP import/install function.
5. Enable the mod if required.
6. Open `Options -> CHEATS`.
7. Configure the desired cheats.

Do not use GitHub's automatic `Source code.zip` or `Source code.tar.gz` downloads. Those archives are not the installable mod package.

Download the specifically named release asset instead.

## Development

Contributors should edit the unzipped repository files directly, especially `main.lua`, and then submit commits or pull requests.

Keep changes non-invasive where practical and prefer public Gen1Recomp Mod API hooks/events over core file replacement.

Test gameplay changes before submitting. For releases, update `manifest.json` version and `CHANGELOG.md` together when appropriate.

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Nintendo, The Pokémon Company, Game Freak, or the Gen1Recomp developers.

No ROM or Pokémon game assets are included.

Upstream Gen1Recomp repository: https://github.com/bryanthaboi/gen1recomp
