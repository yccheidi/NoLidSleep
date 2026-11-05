# NoLidSleep

Menu bar toggle for `sudo pmset disablesleep 1|0`, so your Mac keeps running with the lid closed.
Unlike Caffeine-style apps, this stops clamshell sleep itself.

## Download

Get the latest `NoLidSleep.dmg` from the [Releases page](https://github.com/yccheidi/NoLidSleep/releases/latest), open it and drag NoLidSleep to Applications.
Requires macOS 13 or later. The app is not notarized, see [Sharing without notarization](#sharing-without-notarization) for the first launch.

## Usage

Three states, each stronger than the last. **Left-click** the icon to cycle Sleep Allowed → Awake, Lid Open → Awake, Lid Closed → Sleep Allowed. **Right-click** (or Ctrl-click) for the menu, where you can jump to a state and pick a duration (clicks use the last chosen duration):

| State | Icon | What it does |
| --- | --- | --- |
| Sleep Allowed | moon and stars | Normal macOS behaviour |
| Awake, Lid Open | open laptop with a sun behind it | Prevents idle system and display sleep (like `caffeinate`) |
| Awake, Lid Closed | closed laptop (top view with logo) with a sun above | Same, plus `pmset disablesleep 1` so closing the lid doesn't sleep |

The last two each have a duration submenu: 30 Minutes, 1, 3, 5, 12 Hours, or Infinite. When the time runs out everything is restored
(`disablesleep 0`, assertions released). Every state change shows a small popup under the icon, and the tooltip shows the time left.

Also: About page, Check for Updates (compares with the latest GitHub release; needs the repo to be public), Launch at Login, On Launch (Sleep Allowed / Awake, Lid Open / Awake, Lid Closed / Remember Last State), and auto-stop below 10% battery when unplugged.

## Passwordless toggle

The first time you pick the lid-closed option, the app asks for your admin password once and writes `/etc/sudoers.d/nolidsleep`,
which allows only `pmset disablesleep 0` and `pmset disablesleep 1` for your user. Remove it from the menu any time
(or `sudo rm /etc/sudoers.d/nolidsleep`).

## Build

```sh
./Scripts/build.sh        # -> build/NoLidSleep.app, .zip and .dmg (universal, ad-hoc signed)
VERSION=0.2.0 ./Scripts/build.sh   # override the version (default 0.1.3)
swift Scripts/make_icon.swift Resources   # regenerate the icon
```

Open the `.dmg` and drag `NoLidSleep.app` to `/Applications`.

## Sharing without notarization

The app is not notarized. On another Mac, first open via right-click > Open, or:

```sh
xattr -cr /Applications/NoLidSleep.app
```

## Heads-up

A closed, running laptop in a bag gets hot and drains the battery. Keep the low-battery protection on.

## License

MIT, see [LICENSE](LICENSE).
