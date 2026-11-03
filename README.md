# NoLidSleep

Menu bar toggle for `sudo pmset disablesleep 1|0`, so your Mac keeps running with the lid closed.
Unlike Caffeine-style apps, this stops clamshell sleep itself.

Three states, each stronger than the last. **Left-click** the icon to cycle Off → Awake → Awake with lid closed → Off. **Right-click** (or Ctrl-click) for the menu, where you can jump to a state and pick a duration (clicks use the last chosen duration):

| State | Icon | What it does |
| --- | --- | --- |
| Sleep Allowed (Off) | moon and stars | Normal macOS behaviour |
| Disable Sleep | open laptop with a sun behind it | Prevents idle system and display sleep (like `caffeinate`) |
| Disable Sleep, Even Lid Closed | closed laptop (top view with logo) with a sun above | Same, plus `pmset disablesleep 1` so closing the lid doesn't sleep |

The last two each have a duration submenu: 30 Minutes, 1, 3, 5, 12 Hours, or Infinite. When the time runs out everything is restored
(`disablesleep 0`, assertions released). Every state change shows a small popup under the icon, and the tooltip shows the time left.

Also: Launch at Login, On Launch (Off / Awake / Awake Even Lid Closed / Remember Last), and auto-stop below 20% battery when unplugged.

## Passwordless toggle

The first time you pick the lid-closed option, the app asks for your admin password once and writes `/etc/sudoers.d/nolidsleep`,
which allows only `pmset disablesleep 0` and `pmset disablesleep 1` for your user. Remove it from the menu any time
(or `sudo rm /etc/sudoers.d/nolidsleep`).

## Build

```sh
./Scripts/build.sh        # -> build/NoLidSleep.app and build/NoLidSleep.zip (universal, ad-hoc signed)
swift Scripts/make_icon.swift Resources   # regenerate the icon
```

Drag `NoLidSleep.app` to `/Applications`.

## Sharing without notarization

The app is not notarized. On another Mac, first open via right-click > Open, or:

```sh
xattr -cr /Applications/NoLidSleep.app
```

### Homebrew cask (own tap)

Upload `build/NoLidSleep.zip` to a GitHub Release, then in a `homebrew-tap` repo add `Casks/nolidsleep.rb`:

```ruby
cask "nolidsleep" do
  version "1.0.0"
  sha256 "<shasum -a 256 build/NoLidSleep.zip>"

  url "https://github.com/<you>/NoLidSleep/releases/download/v#{version}/NoLidSleep.zip"
  name "NoLidSleep"
  desc "Menu bar toggle to keep the Mac awake with the lid closed"
  homepage "https://github.com/<you>/NoLidSleep"

  depends_on macos: ">= :ventura"
  app "NoLidSleep.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/NoLidSleep.app"]
  end

  zap trash: "/etc/sudoers.d/nolidsleep"
end
```

Install: `brew install --cask <you>/tap/nolidsleep`.

## Heads-up

A closed, running laptop in a bag gets hot and drains the battery. Keep the low-battery protection on.
