#!/bin/bash

# iOS Simulator and Cache Cleanup Script
# This script clears out simulator data, Xcode caches, and other development-related files
# to free up significant disk space.

set -e  # Exit on any error

echo "🧹 iOS Simulator and Cache Cleanup Script"
echo "========================================="
echo

# Function to get directory size in human readable format
get_size() {
    if [ -d "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Function to safely remove directory/file
safe_remove() {
    if [ -e "$1" ]; then
        local size=$(get_size "$1")
        echo "  Removing: $1 (Size: $size)"
        rm -rf "$1"
        echo "  ✅ Removed successfully"
    else
        echo "  ℹ️  Not found: $1"
    fi
}

# Calculate initial disk usage
echo "📊 Checking initial disk usage..."
initial_available=$(df -h . | tail -1 | awk '{print $4}')
echo "Available disk space: $initial_available"
echo

# 1. iOS Simulator Data
echo "🔄 Clearing iOS Simulator data..."
SIMULATOR_DIR="$HOME/Library/Developer/CoreSimulator"
if [ -d "$SIMULATOR_DIR" ]; then
    simulator_size=$(get_size "$SIMULATOR_DIR")
    echo "  Current simulator data size: $simulator_size"

    # First, shutdown all simulators
    echo "  Shutting down all simulators..."
    xcrun simctl shutdown all 2>/dev/null || true

    # Erase all simulators
    echo "  Erasing all simulators..."
    xcrun simctl erase all 2>/dev/null || true

    # Remove device sets and cached data
    safe_remove "$SIMULATOR_DIR/Devices"
    safe_remove "$SIMULATOR_DIR/Caches"

    echo "  ✅ iOS Simulator cleanup completed"
else
    echo "  ℹ️  iOS Simulator directory not found"
fi
echo

# 2. Xcode Derived Data
echo "🔄 Clearing Xcode Derived Data..."
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_DIR" ]; then
    derived_data_size=$(get_size "$DERIVED_DATA_DIR")
    echo "  Current derived data size: $derived_data_size"
    safe_remove "$DERIVED_DATA_DIR"
    echo "  ✅ Derived Data cleanup completed"
else
    echo "  ℹ️  Derived Data directory not found"
fi
echo

# 3. Xcode Archives
echo "🔄 Clearing Xcode Archives..."
ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
if [ -d "$ARCHIVES_DIR" ]; then
    archives_size=$(get_size "$ARCHIVES_DIR")
    echo "  Current archives size: $archives_size"
    safe_remove "$ARCHIVES_DIR"
    echo "  ✅ Archives cleanup completed"
else
    echo "  ℹ️  Archives directory not found"
fi
echo

# 4. iOS Device Support files
echo "🔄 Clearing iOS Device Support files..."
DEVICE_SUPPORT_DIR="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
if [ -d "$DEVICE_SUPPORT_DIR" ]; then
    device_support_size=$(get_size "$DEVICE_SUPPORT_DIR")
    echo "  Current device support size: $device_support_size"
    safe_remove "$DEVICE_SUPPORT_DIR"
    echo "  ✅ Device Support cleanup completed"
else
    echo "  ℹ️  Device Support directory not found"
fi
echo

# 5. Xcode Documentation Cache
echo "🔄 Clearing Xcode Documentation Cache..."
DOC_CACHE_DIR="$HOME/Library/Developer/Shared/Documentation/DocC"
safe_remove "$DOC_CACHE_DIR"
echo

# 6. Swift Package Manager Cache
echo "🔄 Clearing Swift Package Manager cache..."
SPM_CACHE_DIR="$HOME/Library/Caches/org.swift.swiftpm"
if [ -d "$SPM_CACHE_DIR" ]; then
    spm_size=$(get_size "$SPM_CACHE_DIR")
    echo "  Current SPM cache size: $spm_size"
    safe_remove "$SPM_CACHE_DIR"
    echo "  ✅ SPM cache cleanup completed"
else
    echo "  ℹ️  SPM cache directory not found"
fi
echo

# 7. Xcode User Data (logs, breakpoints, etc.)
echo "🔄 Clearing Xcode User Data..."
USER_DATA_DIRS=(
    "$HOME/Library/Developer/Xcode/UserData/IDEEditorInteractivity.plist"
    "$HOME/Library/Developer/Xcode/UserData/IB Support"
    "$HOME/Library/Developer/Xcode/UserData/xcschemes"
)

for dir in "${USER_DATA_DIRS[@]}"; do
    safe_remove "$dir"
done
echo

# 8. iOS Simulator Screenshots and Videos
echo "🔄 Clearing Simulator Screenshots and Videos..."
SIMULATOR_MEDIA="$HOME/Desktop/Simulator Screen Shot*"
SIMULATOR_VIDEOS="$HOME/Desktop/Simulator Screen Recording*"

# Remove simulator screenshots
if ls $SIMULATOR_MEDIA 1> /dev/null 2>&1; then
    echo "  Removing simulator screenshots from Desktop..."
    rm -f $SIMULATOR_MEDIA
    echo "  ✅ Screenshots removed"
else
    echo "  ℹ️  No simulator screenshots found on Desktop"
fi

# Remove simulator videos
if ls $SIMULATOR_VIDEOS 1> /dev/null 2>&1; then
    echo "  Removing simulator videos from Desktop..."
    rm -f $SIMULATOR_VIDEOS
    echo "  ✅ Videos removed"
else
    echo "  ℹ️  No simulator videos found on Desktop"
fi
echo

# 9. CocoaPods Cache (if using CocoaPods)
echo "🔄 Clearing CocoaPods cache..."
COCOAPODS_CACHE="$HOME/Library/Caches/CocoaPods"
if [ -d "$COCOAPODS_CACHE" ]; then
    pods_size=$(get_size "$COCOAPODS_CACHE")
    echo "  Current CocoaPods cache size: $pods_size"
    safe_remove "$COCOAPODS_CACHE"
    echo "  ✅ CocoaPods cache cleanup completed"
else
    echo "  ℹ️  CocoaPods cache not found"
fi
echo

# 10. Carthage Cache (if using Carthage)
echo "🔄 Clearing Carthage cache..."
CARTHAGE_CACHE="$HOME/Library/Caches/org.carthage.CarthageKit"
if [ -d "$CARTHAGE_CACHE" ]; then
    carthage_size=$(get_size "$CARTHAGE_CACHE")
    echo "  Current Carthage cache size: $carthage_size"
    safe_remove "$CARTHAGE_CACHE"
    echo "  ✅ Carthage cache cleanup completed"
else
    echo "  ℹ️  Carthage cache not found"
fi
echo

# 11. System Caches (be careful with these)
echo "🔄 Clearing additional system caches..."
SYSTEM_CACHES=(
    "$HOME/Library/Caches/com.apple.dt.Xcode"
    "$HOME/Library/Caches/com.apple.CoreSimulator.CoreSimulatorService"
    "$HOME/Library/Logs/CoreSimulator"
    "$HOME/Library/Logs/DiagnosticReports/Simulator*"
)

for cache in "${SYSTEM_CACHES[@]}"; do
    safe_remove "$cache"
done
echo

# 12. Clean up any remaining simulator logs
echo "🔄 Clearing simulator logs..."
SIMULATOR_LOGS="$HOME/Library/Logs/CoreSimulator"
if [ -d "$SIMULATOR_LOGS" ]; then
    logs_size=$(get_size "$SIMULATOR_LOGS")
    echo "  Current simulator logs size: $logs_size"
    safe_remove "$SIMULATOR_LOGS"
    echo "  ✅ Simulator logs cleanup completed"
else
    echo "  ℹ️  Simulator logs directory not found"
fi
echo

# 13. Optional: Clean up old Xcode installations (commented out for safety)
# echo "🔄 Cleaning up old Xcode installations..."
# XCODE_APPS=(/Applications/Xcode*.app)
# if [ ${#XCODE_APPS[@]} -gt 1 ]; then
#     echo "  Found multiple Xcode installations:"
#     for app in "${XCODE_APPS[@]}"; do
#         if [ -d "$app" ]; then
#             app_size=$(get_size "$app")
#             echo "    $app (Size: $app_size)"
#         fi
#     done
#     echo "  ⚠️  Manual cleanup recommended for old Xcode versions"
# fi

# Final disk usage check
echo "📊 Checking final disk usage..."
final_available=$(df -h . | tail -1 | awk '{print $4}')
echo "Available disk space: $final_available"
echo

# Restart simulator service for clean state
echo "🔄 Restarting Simulator service..."
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
echo "  ✅ Simulator service restarted"
echo

echo "🎉 Cleanup completed successfully!"
echo "========================================="
echo "📈 Disk space freed up: Check the difference between initial ($initial_available) and final ($final_available) available space"
echo
echo "💡 Recommendations:"
echo "   • Run this script periodically to maintain clean development environment"
echo "   • Consider moving large projects to external storage"
echo "   • Use 'xcrun simctl list devices' to verify simulator cleanup"
echo "   • Restart Xcode to ensure all changes take effect"
echo
echo "✅ All done! Your development environment is now cleaned up."