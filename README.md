# orbit-finance-releases

Public installers for Orbit Finance, a Built by Pali product. Source is private.

## Download

**[Get the latest version](https://github.com/wmfadzli/orbit-finance-releases/releases/latest)**

On the release page, open **Assets** and pick the file for your device:

| Device | File | Notes |
| --- | --- | --- |
| Mac (Apple Silicon and Intel) | `Orbit.Finance-<version>-universal.dmg` | Open the DMG and drag Orbit Finance into Applications |
| Windows 10 / 11 | `Orbit.Finance.Setup.<version>.exe` | Run the installer and follow the steps |
| Android | `Orbit.Finance-<version>.apk` | Allow "Install unknown apps" for your browser when asked |
| Chromebook (Intel/AMD) | `Orbit.Finance-<version>-amd64.deb` | Needs Linux turned on, see below |
| Chromebook (ARM: MediaTek, Snapdragon) | `Orbit.Finance-<version>-arm64.deb` | Needs Linux turned on, see below |

## Chromebook (ChromeOS)

The Windows `.exe` won't open on a Chromebook. Use the `.deb` file instead:

1. Turn on Linux once: **Settings > About ChromeOS > Developers > Linux development environment > Set up**.
2. Check your chip: **Settings > About ChromeOS > Additional details**. Intel, AMD or Celeron means `amd64`. MediaTek or Snapdragon means `arm64`.
3. Download the matching `.deb` and double-click it in **Files**, then choose **Install**.
4. Open Orbit Finance from the launcher (it sits in the **Linux apps** folder).

## Install tips

- **Mac:** if macOS says the app can't be opened, right-click the app in Applications and choose **Open**, then **Open** again.
- **Windows:** if SmartScreen shows "Windows protected your PC", click **More info**, then **Run anyway**.
- **Android:** after installing, you can switch "Install unknown apps" back off.

## Updates

The desktop app checks for new versions and offers to update in-app. You can also come back here any time for the newest installer.

## What's new

See the [release notes](https://github.com/wmfadzli/orbit-finance-releases/releases) for every version.
