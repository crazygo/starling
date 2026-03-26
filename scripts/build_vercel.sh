#!/bin/bash
set -e

FLUTTER_HOME="$HOME/flutter"

# Install Flutter SDK if not already present at FLUTTER_HOME
if [ ! -f "$FLUTTER_HOME/bin/flutter" ]; then
    echo "Flutter not found. Installing Flutter SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"

# Verify installation and trigger initial SDK setup
flutter --version

# Enable web platform support
flutter config --enable-web

# Install project dependencies
flutter pub get

# Ensure the assets/bin/ directory exists (FlatBuffers catalogs are generated
# locally by the data pipeline in tool/; the directory must exist for the
# Flutter asset bundle even when the .bin files are not yet generated).
mkdir -p assets/bin

# Generate localization files (from lib/l10n/*.arb → lib/l10n/generated/)
flutter gen-l10n

# Build web release
flutter build web --release --no-wasm
