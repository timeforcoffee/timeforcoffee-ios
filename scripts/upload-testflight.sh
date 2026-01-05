#!/bin/bash
set -e

# Load .env file if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Configuration
WORKSPACE="timeforcoffee.xcworkspace"
SCHEME="timeforcoffee"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/timeforcoffee.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="ExportOptions.plist"

# Authentication - supports two methods:
# Method 1: Apple ID + App-specific password (set APPLE_ID and APPLE_APP_PASSWORD or use keychain)
# Method 2: App Store Connect API Key (set ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
KEYCHAIN_ITEM="${KEYCHAIN_ITEM:-AC_PASSWORD}"

# API Key auth (preferred)
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_KEY_PATH="${ASC_KEY_PATH:-}"

# Keychain unlock (optional, for headless/CI builds)
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

# Verbose mode (set VERBOSE=0 to disable detailed logging)
VERBOSE="${VERBOSE:-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_step() {
    echo -e "${GREEN}==>${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

echo_error() {
    echo -e "${RED}Error:${NC} $1"
}

echo_verbose() {
    if [ "$VERBOSE" = "1" ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
    fi
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

unlock_keychain() {
    if [ -n "$KEYCHAIN_PASSWORD" ]; then
        echo_step "Unlocking keychain for codesign..."
        echo_verbose "Unlocking keychain: $KEYCHAIN_PATH"
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
        echo_verbose "Setting keychain timeout to 1 hour"
        security set-keychain-settings -t 3600 -u "$KEYCHAIN_PATH"
        echo_verbose "Setting key partition list for codesign access"
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>/dev/null || true
        echo_verbose "Keychain unlocked successfully"
    else
        echo_verbose "No KEYCHAIN_PASSWORD set, skipping keychain unlock"
    fi
}

# Change to project root
cd "$(dirname "$0")/.."

# Determine auth method
USE_API_KEY=false
if [ -n "$ASC_KEY_ID" ] && [ -n "$ASC_ISSUER_ID" ] && [ -n "$ASC_KEY_PATH" ]; then
    USE_API_KEY=true
    echo_step "Using App Store Connect API Key authentication"
elif [ -n "$APPLE_ID" ]; then
    echo_step "Using Apple ID authentication"
else
    echo_error "No authentication configured"
    echo ""
    echo "Option 1 - Apple ID (simpler):"
    echo "  APPLE_ID=your@email.com APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx $0"
    echo ""
    echo "Option 2 - API Key (recommended, no 2FA issues):"
    echo "  1. Create key at https://appstoreconnect.apple.com/access/api"
    echo "  2. ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxx-xxx ASC_KEY_PATH=~/.keys/AuthKey.p8 $0"
    echo ""
    echo "For CI/CD or headless builds, also set KEYCHAIN_PASSWORD to unlock keychain for codesign."
    exit 1
fi

if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo_error "ExportOptions.plist not found"
    exit 1
fi

# Show configuration in verbose mode
if [ "$VERBOSE" = "1" ]; then
    echo_verbose "Configuration:"
    echo_verbose "  Workspace: $WORKSPACE"
    echo_verbose "  Scheme: $SCHEME"
    echo_verbose "  Archive Path: $ARCHIVE_PATH"
    echo_verbose "  Export Options: $EXPORT_OPTIONS"
    echo_verbose "  Auth Method: $([ "$USE_API_KEY" = true ] && echo "API Key" || echo "Apple ID")"
fi

# Clean build directory
echo_step "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive
echo_step "Archiving $SCHEME... (started at $(timestamp))"
ARCHIVE_START=$(date +%s)

if [ "$VERBOSE" = "1" ]; then
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS'
else
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        -quiet
fi

ARCHIVE_END=$(date +%s)
echo_verbose "Archive completed in $((ARCHIVE_END - ARCHIVE_START)) seconds"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo_error "Archive failed"
    exit 1
fi
echo_step "Archive created: $ARCHIVE_PATH"

# Unlock keychain before export (codesign runs during export)
unlock_keychain

# Export IPA
echo_step "Exporting IPA... (started at $(timestamp))"
EXPORT_START=$(date +%s)

if [ "$VERBOSE" = "1" ]; then
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        2>&1 | while IFS= read -r line; do
            echo "[$(date '+%H:%M:%S')] $line"
        done
else
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -quiet
fi

EXPORT_END=$(date +%s)
echo_verbose "Export completed in $((EXPORT_END - EXPORT_START)) seconds"

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
if [ -z "$IPA_FILE" ]; then
    echo_error "Export failed - no IPA found"
    exit 1
fi
echo_step "IPA created: $IPA_FILE"

# Upload to TestFlight
echo_step "Uploading to TestFlight... (started at $(timestamp))"
UPLOAD_START=$(date +%s)

if [ "$USE_API_KEY" = true ]; then
    xcrun altool --upload-app \
        -f "$IPA_FILE" \
        -t ios \
        --apiKey "$ASC_KEY_ID" \
        --apiIssuer "$ASC_ISSUER_ID"
else
    if [ -n "$APPLE_APP_PASSWORD" ]; then
        xcrun altool --upload-app \
            -f "$IPA_FILE" \
            -t ios \
            -u "$APPLE_ID" \
            -p "$APPLE_APP_PASSWORD"
    else
        xcrun altool --upload-app \
            -f "$IPA_FILE" \
            -t ios \
            -u "$APPLE_ID" \
            -p "@keychain:$KEYCHAIN_ITEM"
    fi
fi

UPLOAD_END=$(date +%s)
echo_verbose "Upload completed in $((UPLOAD_END - UPLOAD_START)) seconds"

echo_step "Upload complete! Check App Store Connect for processing status."
echo_verbose "Total time: Archive=$((ARCHIVE_END - ARCHIVE_START))s, Export=$((EXPORT_END - EXPORT_START))s, Upload=$((UPLOAD_END - UPLOAD_START))s"
