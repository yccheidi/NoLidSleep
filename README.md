# NoLidSleep

Menu bar toggle for `sudo pmset disablesleep 1|0`, so your Mac keeps running with the lid closed.
Unlike Caffeine-style apps, this stops clamshell sleep itself.

Works like KeepingYouAwake, with an extra lid-closed mode:

- **Left-click** the icon: start/stop keeping the Mac awake (empty cup = off, filled cup = awake). **Right-click** (or Ctrl-click): menu.
- **Also Keep Awake with Lid Closed**: only selectable while awake. Runs `pmset disablesleep 1`; the icon becomes a laptop. Turning the session off (or when it expires) restores `disablesleep 0`.
- **Duration**: 15 min ... 12 h, or Infinite. Applies to the whole session including lid mode; a countdown shows in the tooltip and menu.
- **Keep Display On**, **Launch at Login**, **On Launch** (Start Awake / Start Off / Remember Last State).
- Auto-stops below 20% battery when unplugged (can be disabled).

## Passwordless toggle

The first time you enable lid mode, the app asks for your admin password once and writes `/etc/sudoers.d/nolidsleep`,
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
