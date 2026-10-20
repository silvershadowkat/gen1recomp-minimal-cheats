# Native follower transition checks

These Lua chunks accept `(game, shared)` in an initialized, disposable diagnostic session on engine 0.3.91. Disable all save writers before running them; they deliberately change the in-memory party or map and must not run against unsaved user progress.

- `followers_gen1.lua`: requires an active follower pack. Loads Pallet Town, checks warp gathering, then runs the real Route 1 connection with followers mid-step. Checks entity identity, pixel/target rebasing, trail history and animation progress. Yellow additionally requires an eligible original-OT starter Pikachu and checks identity, no duplicate and unchanged happiness.
- `followers_gen2.lua`: creates a six-member test party, checks warp gathering, then runs the real New Bark/Route 29 connection. Checks the native primary and five extra followers.
- `followers_gen3.lua`: start at Pallet Town (FRLG) or Oldale Town (RSE). Runs the native north connection and checks all six trail positions; then checks the warp-event reset.

Executed on Nova with Blue, Yellow, Crystal, FireRed and Emerald for 3.1.4. Blue's house entry/exit and restored intro/title were also inspected visually. The separate `test_follower_transitions.lua` runs without ROMs and covers fractional pixels, negative coordinates, failed connections, independent trail cells and warp reset.
