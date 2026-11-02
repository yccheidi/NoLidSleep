# NoLidSleep

Menu bar toggle for `sudo pmset disablesleep 1|0`, so your Mac keeps running with the lid closed.
Unlike Caffeine-style apps, this stops clamshell sleep itself.

- Menu bar icon: laptop = awake with lid closed (`SleepDisabled 1`), slashed laptop = normal (`0`). Re-read from `pmset -g` every 3 s, so changes made in Terminal show up too.
- Click the icon to toggle.
- **Launch at Login** (macOS 13+, `SMAppService`).
- **On Launch**: Turn On / Turn Off / Remember Last State (needs Launch at Login to take effect at boot).
- Optional: turn off automatically below 20% battery when unplugged.

## Passwordless toggle

On first toggle, the app asks for your admin password once and writes `/etc/sudoers.d/nolidsleep`,
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
