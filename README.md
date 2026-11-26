# BeyondMenu

An independent menu for Drive Beyond Horizons. Press **F8** in a loaded game to open or close it.

## Features

- A compact **Fun** tab with a paintball gun, reusable canisters and a color wheel.
- **Flight / noclip** and **Open Computer** in the Player tab.
- Player health, hunger, thirst, empty bladder, money, super speed and super jump.
- A scoreboard with names and ping. The host can teleport to a player, bring a player over, or restore their health, hunger and thirst.
- A searchable item catalog using the installed game's item data and native icons, with extra thumbnails for parts missing native icons.
- Unlimited brushes, sponges, spraypaint and ammunition for native bullet weapons.
- A spraypaint maker with a color wheel and metallic or matte finish.
- A car catalog with pictures, a preview after hovering for one second, and a **Tuned parts** checkbox that changes both the preview and the spawned car. **Car color** opens a color wheel with metallic and matte finishes; the pictures and preview use your chosen paint.
- Time and weather controls.
- Rounded buttons, adjustable borders, background and button colors, and transparent or solid backgrounds. The toolbox icon in Settings opens the native debug menu.

BeyondMenu does not include Apocalypse, Tuning, a personal menu, or any other mod. Optional Apocalypse and Tuning items appear when their installed providers are active. The Hornet gyrocopter, Classic motorcycle, Suzuki PV 50 and landing-pad trailer appear only in the car spawner. The personal menu retains F7, and BeyondMenu has its own state and settings.

## Install

With the game closed, drag the unopened Nexus ZIP into Beyond Mod Manager and click Install. BMM checks UE4SS during installation. To enable the optional Apocalypse or Tuning items, run the included installer once after installing those mods.

For a manual installation:

1. Install a compatible UE4SS loader. This build was tested with UE4SS 3.0.1 beta, commit `8f7b2ca3`, and game build `26437602`.
2. Close the game and extract the whole ZIP.
3. Run `Install.ps1` with PowerShell. For a different Steam library, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Drive Beyond Horizons"
```

The installer enables only BeyondMenu. When Apocalypse or Tuning is already installed, it adds a small optional provider loader and keeps a backup of the original entry point. It does not change your personal menu files or shortcut. Re-run the installer after adding or replacing one of those optional mods.

You can also extract the `DriveBeyondHorizons` folder into the game folder for the standalone menu. Use the installer to enable optional Beyond item support.

## Updates

Public releases: https://github.com/lionlord513/beyond-menu/releases

Beyond Mod Manager can use the included update metadata. No manager is required: run `Update.ps1` from the extracted download (use `-GamePath` for a custom Steam library) to fetch and install the latest release automatically. It checks the package checksum, preserves your settings, and requires the game to be closed. Add `-CheckOnly` to check without installing.

## Use

In a solo or host game, open **Fun**, choose a color on the wheel, and press **Spawn 50 paintballs**. The selected color appears in the clear canister. Spawn the gun, pick it up, aim at the canister within reach, and press **L** at **Load paintballs**. Matching paint tops up the gun to 50 rounds and leaves excess paintballs in the canister. A different color swaps the two loads, returning any previous rounds to the canister. Empty canisters stay in the world and have no loading prompt. Equip the gun and use the primary mouse button to fire. Rotate loose items with the game's middle-mouse control.

Repeated hits near fresh paint can produce drips or pools. BeyondMenu saves the paint, canister contents and gun loads in `BeyondMenu/state/`, keyed to the game's save revisions. Include this folder when moving or backing up a painted world. A painted object needs to be loaded for its paint to be visible.

In **Player**, switch on **Flight / noclip** to fly with WASD. Space ascends, left Ctrl descends and either Shift key increases speed. Switch flight off to restore collision. **Open Computer** opens the native desktop. Press Escape to close it and return to the game.

Click an item or car to spawn it. Stand on foot with clear space nearby. **Tuned parts** uses the game's available tuning kit; vehicles without a tuning kit keep their standard parts. Catalog entries come from the installed game, and current vehicle preview images were captured from build `26437602`. Paint changes the parts that the vehicle supports painting; glass, tires and unpaintable trim retain their materials. Optional vehicles finish assembling before their paint is applied.

Player stat changes, world controls, optional item spawning and scoreboard actions require the host. Guests can browse, use their own wallet and movement tools, request native items, and use the native garage delivery route for cars. Guest vehicle deliveries can take a while; do not send duplicate requests.

Close another menu before opening BeyondMenu. Press Escape to go back or close. Theme preferences are stored in `settings.ini` inside the BeyondMenu folder. No console commands, remote command endpoint or developer unlock is included. The included Windows helper renders painted thumbnails and reads the game-window pointer; it does not send input or make network requests. Its source is in `native/`.

Run `Uninstall.ps1` to disable BeyondMenu and remove its optional provider loaders. Its settings are kept.

## Credits

By lionlord513 / Beyond Mods. Built from the author's existing menu functionality and the game's native APIs. No ZodMenu source or packaged assets are included. Drive Beyond Horizons and Unreal Engine assets belong to their respective owners.

The marker uses [Paintball Gun by Judith Solomon](https://sketchfab.com/3d-models/paintball-gun-c9f3b8079102454fb9d3fc628ff0ad8b), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). BeyondMenu converts and reorients the mesh, rebinds its textures to in-game materials and fits a new collision shape to it.

The firing recording is [paintball_shoot1.wav by fabianofa](https://freesound.org/people/fabianofa/sounds/98189/). The impact clips are excerpts from [Paintball, tirs et impacts bois by Joseph SARDIN](https://bigsoundbank.com/paintball-tirs-impacts-bois-s0529.html). Both recordings are distributed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
