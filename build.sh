#!/bin/bash

# 1. Clone Flutter shallowly to save time
if [ -d "flutter" ]; then
  echo "Flutter directory exists, pulling updates..."
  cd flutter && git pull && cd ..
else
  echo "Cloning clean Flutter SDK..."
  git clone --depth 1 https://github.com/flutter/flutter.git
fi

# 2. Map pathing parameters
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Configure and activate the web target environment
flutter config --enable-web

# 4. Generate SQLite Drift classes (Required for your app)
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 5. Build your release distribution application safely
flutter build web --release --dart-define=FLUTTER_WEB_DEFAULT_RENDERER=canvaskit
