#!/bin/bash

# 1. Clone Flutter stable cleanly with release tags intact
if [ -d "flutter" ]; then
  echo "Flutter directory exists, pulling updates..."
  cd flutter && git pull --tags && cd ..
else
  echo "Cloning clean Flutter SDK with release tags..."
      git clone --depth 1 --branch stable https://github.com
fi

# 2. Map pathing parameters
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Configure and activate the web target environment
flutter config --enable-web

# 4. Resolve web dependencies
flutter pub get

# 5. Generate SQLite Drift classes
flutter pub run build_runner build --delete-conflicting-outputs

# 6. Build your web deployment package
flutter build web --release --dart-define=FLUTTER_WEB_DEFAULT_RENDERER=canvaskit
