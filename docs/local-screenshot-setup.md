# Local Screenshot Setup

This document records the machine preparation steps used to run local Flutter
web screenshots for the Voyage/Explore view.

The goal is to make it fast to reproduce the same setup after a machine reset
or on a fresh instance.

## What We Needed

To take a local screenshot of the app, we needed:

- a local Flutter SDK
- project dependencies resolved with Flutter
- a built web app
- a local HTTP server for `build/web`
- Playwright + Chromium
- required Linux GUI/runtime libraries for headless Chromium

## One-Time Local SDK Setup

We installed a local Flutter SDK inside the repo workspace:

```bash
git clone https://github.com/flutter/flutter.git -b stable /workspaces/starling/.tooling/flutter
```

Useful binaries:

```bash
/workspaces/starling/.tooling/flutter/bin/flutter --version
/workspaces/starling/.tooling/flutter/bin/dart --version
```

## Project Bootstrap

Run these inside the repo:

```bash
/workspaces/starling/.tooling/flutter/bin/flutter pub get
/workspaces/starling/.tooling/flutter/bin/flutter gen-l10n
```

If needed:

```bash
/workspaces/starling/.tooling/flutter/bin/flutter analyze lib test
/workspaces/starling/.tooling/flutter/bin/flutter test
```

## Build Web Locally

```bash
/workspaces/starling/.tooling/flutter/bin/flutter build web --release
```

This produces:

- `build/web/`

## Local Node / Screenshot Tooling

We created a temporary Node workspace for screenshot tooling:

```bash
mkdir -p /tmp/starling-shot
cd /tmp/starling-shot
npm init -y
npm install playwright serve wait-on
```

Install Chromium for Playwright:

```bash
cd /tmp/starling-shot
npx playwright install chromium
```

## Linux Browser Dependency Fix

The first local Playwright run failed because Chromium was missing Linux shared
libraries such as `libatk-1.0.so.0`.

We also found that `apt` was blocked by an invalid Yarn apt source:

- original file: `/etc/apt/sources.list.d/yarn.list`
- machine state after workaround: `/etc/apt/sources.list.d/yarn.list.disabled`

Temporary workaround used:

```bash
sudo mv /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.list.disabled
sudo apt-get update
sudo apt-get install -y \
  libatk1.0-0 \
  libatk-bridge2.0-0 \
  libatspi2.0-0 \
  libcups2t64 \
  libgtk-3-0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxrandr2 \
  libgbm1 \
  libpango-1.0-0 \
  libcairo2 \
  libasound2t64
```

After that, Playwright screenshots were able to run locally.

## Serve the Built Web App

Start a local server in a long-running shell:

```bash
cd /tmp/starling-shot
npx serve -s /workspaces/starling/build/web -l 8080
```

## Run the Repo Screenshot Script

In another shell:

```bash
cd /tmp/starling-shot
npx wait-on http://localhost:8080 --timeout 30000

cd /workspaces/starling
rm -rf screenshots
NODE_PATH=/tmp/starling-shot/node_modules node .github/scripts/screenshot.js
```

Generated outputs:

- `screenshots/home.png`
- `screenshots/explore.png`
- `screenshots/settings.png`

## View the Result

The most relevant file for Voyage/Explore review is:

- `screenshots/explore.png`

## Repo Files / Workflows Involved

- [`.github/workflows/pr-screenshot.yml`](/workspaces/starling/.github/workflows/pr-screenshot.yml)
- [`.github/scripts/screenshot.js`](/workspaces/starling/.github/scripts/screenshot.js)

## Local Side Effects

These local-only artifacts were created during setup and are currently untracked:

- `.tooling/`
- `pubspec.lock`
- `screenshots/`
- `android/app/src/main/java/`
- `ios/Flutter/`
- `ios/Runner/GeneratedPluginRegistrant.h`
- `ios/Runner/GeneratedPluginRegistrant.m`

These were not intended for the PR itself.

## Recommended Quick Start On a Fresh Machine

```bash
git clone https://github.com/flutter/flutter.git -b stable /workspaces/starling/.tooling/flutter
/workspaces/starling/.tooling/flutter/bin/flutter pub get
/workspaces/starling/.tooling/flutter/bin/flutter gen-l10n
/workspaces/starling/.tooling/flutter/bin/flutter build web --release

mkdir -p /tmp/starling-shot
cd /tmp/starling-shot
npm init -y
npm install playwright serve wait-on
npx playwright install chromium

cd /tmp/starling-shot
npx serve -s /workspaces/starling/build/web -l 8080
```

Then, in a second shell:

```bash
cd /tmp/starling-shot
npx wait-on http://localhost:8080 --timeout 30000

cd /workspaces/starling
rm -rf screenshots
NODE_PATH=/tmp/starling-shot/node_modules node .github/scripts/screenshot.js
```
