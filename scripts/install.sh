#!/bin/bash
set -e

APP_ID="org.zpb.halo"
SRC_DIR="$(dirname "$0")/../src"

echo "==> Building $(APP_ID) ..."
cd "$SRC_DIR"
zip -r "/tmp/$(APP_ID).plasmoid" . -x '.git/*' -x '*~'

echo "==> Installing ..."
kpackagetool5 --type Plasma/Applet --install "/tmp/$(APP_ID).plasmoid" 2>/dev/null || \
kpackagetool5 --type Plasma/Applet --upgrade "/tmp/$(APP_ID).plasmoid"

echo "==> Done. Add 'HALO' from widget list."
