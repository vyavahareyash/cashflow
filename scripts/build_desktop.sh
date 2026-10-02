#!/usr/bin/env bash
set -euo pipefail

VERSION=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
echo "Building Cashflow Desktop v${VERSION}..."

flutter pub get

PLATFORM="$(uname -s)"
case "${PLATFORM}" in
  Darwin*)
    echo "Detected macOS. Building release app and DMG..."
    flutter build macos --release
    
    mkdir -p build/dist build/staging/dmg-source
    cp -r build/macos/Build/Products/Release/cashflow.app build/staging/dmg-source/
    ln -sf /Applications build/staging/dmg-source/Applications
    
    DMG_PATH="build/dist/cashflow-v${VERSION}-macos.dmg"
    rm -f "${DMG_PATH}"
    if command -v diskutil >/dev/null 2>&1 && diskutil help image create from >/dev/null 2>&1; then
      diskutil image create from --format UDZO --volumeName "Cashflow" build/staging/dmg-source "${DMG_PATH}"
    else
      hdiutil create -volname "Cashflow" -srcfolder build/staging/dmg-source -ov -format UDZO "${DMG_PATH}"
    fi
    rm -rf build/staging/dmg-source
    
    echo "✓ Built: ${DMG_PATH}"
    echo "✓ App bundle: build/macos/Build/Products/Release/cashflow.app"
    ;;
  Linux*)
    echo "Detected Linux. Building release app and DEB..."
    flutter build linux --release
    
    STAGING_DIR="build/staging/deb-package"
    mkdir -p build/dist "${STAGING_DIR}/DEBIAN" "${STAGING_DIR}/usr/bin" "${STAGING_DIR}/usr/lib/cashflow" "${STAGING_DIR}/usr/share/applications" "${STAGING_DIR}/usr/share/icons/hicolor/512x512/apps"
    cp -r build/linux/x64/release/bundle/* "${STAGING_DIR}/usr/lib/cashflow/"
    chmod +x "${STAGING_DIR}/usr/lib/cashflow/cashflow"
    ln -sf /usr/lib/cashflow/cashflow "${STAGING_DIR}/usr/bin/cashflow"
    cp assets/icon/playstore_icon_512.png "${STAGING_DIR}/usr/share/icons/hicolor/512x512/apps/cashflow.png"
    
    cat << 'EOF' > "${STAGING_DIR}/usr/share/applications/cashflow.desktop"
[Desktop Entry]
Name=Cashflow
Comment=Personal Finance & Cashflow Tracking
Exec=/usr/bin/cashflow
Icon=cashflow
Terminal=false
Type=Application
Categories=Office;Finance;
EOF

    cat << EOF > "${STAGING_DIR}/DEBIAN/control"
Package: cashflow
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Yash Vyavahare
Description: Offline-first personal finance and cashflow management app.
EOF

    DEB_PATH="build/dist/cashflow-v${VERSION}-linux-amd64.deb"
    dpkg-deb --build --root-owner-group "${STAGING_DIR}" "${DEB_PATH}"
    rm -rf "${STAGING_DIR}"
    echo "✓ Built: ${DEB_PATH}"
    ;;
  *)
    echo "Unsupported OS for automatic shell build: ${PLATFORM}. For Windows, build with: flutter build windows --release && iscc windows/installer/cashflow.iss"
    exit 1
    ;;
esac
