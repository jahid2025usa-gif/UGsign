<div align="center">

<img title="UG Sign" alt="UG Sign" height="180" src="landing.png">

# UG Sign

On-device IPA signer and app manager for iOS and iPadOS.

</div>

UG Sign is a free, open-source sideloading app for developer certificates. It signs and installs IPA files directly on your device, with an eSign-inspired interface.

## Features

- Sign and install applications on-device.
- Browse, import, sign and manage IPA files from a built-in file browser.
- Supports [AltStore](https://faq.altstore.io/distribute-your-apps/make-a-source#apps) repositories.
- View detailed app, certificate and bundle information.
- Configurable signing options, including bundle ID, version, icon and entitlements.
- Tweak injection with [ElleKit](https://github.com/tealbathingsuit/ellekit) support for `.deb` and `.dylib` files.
- Dark interface with the UG Sign blue theme.
- No tracking or analytics.

## Download

Get the latest `.ipa` from [Releases](https://github.com/jahid2025usa-gif/UGsign/releases/latest).

## Build

The standard Xcode build:

```sh
make iphoneos
```

This produces `packages/UGSign.ipa`.

On Linux, the `xtool-build/` wrapper can build the same sources with [xtool](https://github.com/xtool-org/xtool) and a Darwin Swift SDK:

```sh
cd xtool-build
xtool dev build --ipa
```

## Website & Community

- Website: [ios-ug.github.io](https://ios-ug.github.io)
- Telegram: [t.me/UGios](https://t.me/UGios)

## License

UG Sign is distributed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

It is based on [Feather](https://github.com/claration/Feather), also licensed under GPL-3.0. The original copyright notices are retained in the source files as required by the license.
