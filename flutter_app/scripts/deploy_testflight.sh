#!/bin/bash
set -e

# ============================================================
# Paynow MM — Build & Upload to TestFlight
# ============================================================
# Usage:
#   ./scripts/deploy_testflight.sh              (build + open Organizer)
#   ./scripts/deploy_testflight.sh --bump       (auto-increment build number)
#
# Prerequisites:
#   - Xcode with Apple Distribution certificate
#   - Apple ID logged in to Xcode
#   - flutter on PATH
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"
EXPORT_OPTIONS="$IOS_DIR/ExportOptions.plist"
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
SCHEME="Runner"
WORKSPACE="$IOS_DIR/Runner.xcworkspace"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ---- Pre-flight ----
command -v flutter >/dev/null 2>&1 || err "flutter not found"
command -v xcodebuild >/dev/null 2>&1 || err "xcodebuild not found"

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

# ---- Step 1: Flutter build ----
step "Step 1/4: Flutter build"
cd "$PROJECT_ROOT"
flutter clean > /dev/null 2>&1
log "Cleaned"
flutter pub get > /dev/null 2>&1
log "Dependencies resolved"

flutter build ios --release --no-codesign 2>&1 | grep -E "Built|Error|error:" || true
log "Flutter build complete"

# ---- Step 2: CocoaPods ----
step "Step 2/4: CocoaPods"
cd "$IOS_DIR"
pod install 2>&1 | tail -3
log "Pods installed"

# ---- Step 3: Archive ----
step "Step 3/4: Xcode archive"
TIMESTAMP=$(date +%H.%M)
ARCHIVE_PATH="$ARCHIVE_DIR/Paynow MM ${BUILD_NAME} ($BUILD_NUMBER) $TIMESTAMP.xcarchive"

xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=8R3ZG4Q664 \
    2>&1 | grep -E "Archive Succeeded|error:|warning:" || true

[ -d "$ARCHIVE_PATH" ] || err "Archive failed. Open Xcode to check signing."
log "Archive: $ARCHIVE_PATH"

# ---- Step 4: Export & Upload ----
step "Step 4/4: Export IPA & Upload"

IPA_DIR="$PROJECT_ROOT/build/ios/ipa"
mkdir -p "$IPA_DIR"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$IPA_DIR" \
    -allowProvisioningUpdates \
    2>&1 | grep -E "Export Succeeded|error:" || true

IPA_FILE=$(find "$IPA_DIR" -name "*.ipa" -type f -newer "$0" | head -1)

if [ -f "$IPA_FILE" ]; then
    log "IPA: $IPA_FILE"

    # Try upload via xcrun
    if xcrun altool --upload-app --type ios --file "$IPA_FILE" \
        --apiKey "${APP_STORE_API_KEY:-}" \
        --apiIssuer "${APP_STORE_API_ISSUER:-}" 2>/dev/null; then
        log "Uploaded to App Store Connect!"
    else
        warn "Auto-upload needs API key. Opening Xcode Organizer..."
        open "xcarchive://$ARCHIVE_PATH" 2>/dev/null || open -a Xcode "$ARCHIVE_PATH"
        echo ""
        echo "  ┌─────────────────────────────────────────┐"
        echo "  │  In Xcode Organizer:                    │"
        echo "  │  1. Select the archive                  │"
        echo "  │  2. Click 'Distribute App'              │"
        echo "  │  3. Choose 'TestFlight & App Store'     │"
        echo "  │  4. Click 'Distribute'                  │"
        echo "  └─────────────────────────────────────────┘"
    fi
else
    warn "IPA export failed. Opening archive in Organizer..."
    open -a Xcode "$ARCHIVE_PATH"
    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │  In Xcode Organizer:                    │"
    echo "  │  1. Select the archive                  │"
    echo "  │  2. Click 'Distribute App'              │"
    echo "  │  3. Choose 'TestFlight & App Store'     │"
    echo "  │  4. Click 'Distribute'                  │"
    echo "  └─────────────────────────────────────────┘"
fi

echo ""
log "Done! Check: https://appstoreconnect.apple.com"
