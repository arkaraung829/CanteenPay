#!/bin/bash
set -e

# ============================================================
# Paynow MM — Build Android App Bundle for Play Store
# ============================================================
# Usage:
#   ./scripts/deploy_android.sh              (build release)
#   ./scripts/deploy_android.sh --bump       (auto-increment build number)
#
# Output: build/app/outputs/bundle/release/app-release.aab
# Upload this .aab to Google Play Console
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ---- Bump build number ----
CURRENT_VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: //')
BUILD_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

if [[ "$1" == "--bump" ]]; then
    NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
    sed -i '' "s/^version: .*/version: ${BUILD_NAME}+${NEW_BUILD_NUMBER}/" "$PROJECT_ROOT/pubspec.yaml"
    BUILD_NUMBER=$NEW_BUILD_NUMBER
    log "Build number: $((NEW_BUILD_NUMBER - 1)) → $NEW_BUILD_NUMBER"
fi

echo ""
echo -e "  App:     ${CYAN}Paynow MM${NC}"
echo -e "  Version: ${CYAN}${BUILD_NAME}${NC} (${BUILD_NUMBER})"
echo -e "  Bundle:  ${CYAN}com.canteenpay.canteenPay${NC}"
echo ""

# ---- Step 1: Clean & build ----
step "Step 1/3: Flutter clean & build"
cd "$PROJECT_ROOT"
flutter clean > /dev/null 2>&1
log "Cleaned"
flutter pub get > /dev/null 2>&1
log "Dependencies resolved"

flutter build appbundle --release 2>&1 | tail -5
log "App bundle built"

# ---- Step 2: Verify ----
step "Step 2/3: Verify output"
AAB_FILE="$PROJECT_ROOT/build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_FILE" ]; then
    SIZE=$(du -sh "$AAB_FILE" | cut -f1)
    log "AAB ready: $AAB_FILE ($SIZE)"
else
    echo "[✗] AAB not found!"
    exit 1
fi

# ---- Step 3: Instructions ----
step "Step 3/3: Upload to Play Store"
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Upload to Google Play Console:              │"
echo "  │                                              │"
echo "  │  1. Go to play.google.com/console            │"
echo "  │  2. Select your app                          │"
echo "  │  3. Production → Create new release          │"
echo "  │  4. Upload: app-release.aab                  │"
echo "  │  5. Add release notes → Review → Publish     │"
echo "  └─────────────────────────────────────────────┘"
echo ""
echo "  AAB file: $AAB_FILE"
echo ""
log "Done!"
