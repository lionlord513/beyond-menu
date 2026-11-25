# BeyondMenu

An independent menu for Drive Beyond Horizons. Press **F8** in a loaded game to open or close it.

## Features

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

Beyond Mod Manager can use the included update metadata. No manager is required: run `Update.ps1` inside `ue4ss/Mods/BeyondMenu` to fetch and install the latest release automatically. It checks the package checksum, preserves your settings, and requires the game to be closed. Add `-CheckOnly` to check without installing.

## Use

Click an item or car to spawn it. Stand on foot with clear space nearby. **Tuned parts** uses the game's available tuning kit; vehicles without a tuning kit keep their standard parts. Catalog entries come from the installed game, and current vehicle preview images were captured from build `26437602`. Paint changes the parts that the vehicle supports painting; glass, tires and unpaintable trim retain their materials. Optional vehicles finish assembling before their paint is applied.

Player stat changes, world controls, optional item spawning and scoreboard actions require the host. Guests can browse, use their own wallet and movement tools, request native items, and use the native garage delivery route for cars. Guest vehicle deliveries can take a while; do not send duplicate requests.

Close another menu before opening BeyondMenu. Press Escape to go back or close. Theme preferences are stored in `settings.ini` inside the BeyondMenu folder. No console commands, remote command endpoint or developer unlock is included. The included Windows helper renders painted thumbnails and reads the game-window pointer; it does not send input or make network requests. Its source is in `native/`.

Run `Uninstall.ps1` to disable BeyondMenu and remove its optional provider loaders. Its settings are kept.

## Credits

By lionlord513 / Beyond Mods. Built from the author's existing menu functionality and the game's native APIs. No ZodMenu source or packaged assets are included. Drive Beyond Horizons and Unreal Engine assets belong to their respective owners.
