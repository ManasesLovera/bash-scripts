#!/usr/bin/env bash
# Combined installer: Antigravity 2.0 Desktop App + Antigravity IDE
# For Ubuntu 24.04 LTS
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run with sudo."
    echo "Usage: sudo bash $0"
    exit 1
fi

# ---- Prerequisites ----
info "Installing prerequisites..."
apt update
apt install curl tar desktop-file-utils python3 -y

# ==========================================================================
# Antigravity 2.0 Desktop App
# ==========================================================================
install_antigravity_hub() {
    local download_page="https://antigravity.google/download"
    local install_root="/opt/antigravity"
    local command_link="/usr/local/bin/antigravity"
    local desktop_file="/usr/share/applications/antigravity.desktop"
    local icon_file="/usr/share/icons/hicolor/512x512/apps/antigravity.png"
    local old_icon_file="/usr/share/icons/hicolor/scalable/apps/antigravity.svg"

    case "$(uname -m)" in
        x86_64 | amd64) platform="linux-x64" ;;
        aarch64 | arm64) platform="linux-arm" ;;
        *) error "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac

    for cmd in curl tar python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "$cmd is required but not installed."; return 1
        fi
    done

    local tmp_parent="${TMPDIR:-/var/tmp}"
    mkdir -p "$tmp_parent"
    local tmpdir=$(mktemp -d "$tmp_parent/antigravity.XXXXXX")
    trap 'rm -rf "$tmpdir"' RETURN
    local download_html="$tmpdir/download.html"
    local download_js="$tmpdir/download.js"
    local archive="$tmpdir/Antigravity.tar.gz"
    local archive_list="$tmpdir/archive-list.txt"
    local icon_staged="$tmpdir/antigravity.png"

    info "Fetching Antigravity 2.0 download page..."
    curl -fsSL --compressed --retry 3 -o "$download_html" "$download_page"

    local main_js_url=$(python3 - "$download_html" "$download_page" <<'PY'
import re, sys
from pathlib import Path
from urllib.parse import urljoin
html = Path(sys.argv[1]).read_text()
page_url = sys.argv[2]
matches = re.findall(r'(?:src|href)="([^"]*main-[^"]+\.js)"', html)
if not matches:
    raise SystemExit("Could not find the Antigravity download bundle")
print(urljoin(page_url, matches[-1]))
PY
)

    curl -fsSL --compressed --retry 3 -o "$download_js" "$main_js_url"

    local download_fields=$(python3 - "$download_js" "$platform" <<'PY'
import re, sys
from pathlib import Path
bundle = Path(sys.argv[1]).read_text(errors="replace")
platform = sys.argv[2]
start = bundle.find('id:"antigravity-2"')
end = bundle.find('},{name:"command",id:"antigravity-cli"', start)
if start == -1 or end == -1:
    raise SystemExit("Could not find Antigravity 2.0 downloads")
section = bundle[start:end]
match = re.search(r'href:"([^"]+/' + re.escape(platform) + r'/Antigravity\.tar\.gz)"', section)
if not match:
    raise SystemExit(f"Could not find a download for {platform}")
url = match.group(1)
version_match = re.search(r'/antigravity-hub/([^/]+)/', url)
if not version_match:
    raise SystemExit("Could not parse version from download URL")
print(version_match.group(1).split("-", 1)[0], url)
PY
)
    read -r version download_url <<<"$download_fields"

    if [ -z "$version" ] || [ -z "$download_url" ]; then
        error "Could not parse the Antigravity download page."; return 1
    fi

    case "$platform" in
        linux-x64) expected_top_dir="Antigravity-x64" ;;
        linux-arm) expected_top_dir="Antigravity-arm64" ;;
    esac

    local expected_target="$install_root/$expected_top_dir/antigravity"
    local sandbox_path="$install_root/$expected_top_dir/chrome-sandbox"

    info "Downloading Antigravity 2.0 $version for $platform..."
    curl -fsSL --retry 3 -o "$archive" "$download_url"
    tar -tzf "$archive" >"$archive_list"
    local top_dir=$(sed -n '1{s#/.*##;p;q}' "$archive_list")
    case "$top_dir" in
        Antigravity-*) ;;
        *) error "Unexpected archive layout: $top_dir"; return 1 ;;
    esac
    if [ "$top_dir" != "$expected_top_dir" ]; then
        error "Unexpected archive directory: $top_dir"; return 1
    fi

    tar -xzf "$archive" -C "$tmpdir"
    if [ ! -x "$tmpdir/$top_dir/antigravity" ]; then
        error "The Antigravity launcher was not found in the archive."; return 1
    fi

    info "Extracting icon..."
    python3 - "$tmpdir/$top_dir/resources/app.asar" "$icon_staged" <<'PY'
import json, struct, sys
asar, out = sys.argv[1], sys.argv[2]
with open(asar, "rb") as f:
    f.read(4); struct.unpack("<I", f.read(4)); struct.unpack("<I", f.read(4))
    hdr_len = struct.unpack("<I", f.read(4))[0]
    hdr = f.read(hdr_len)
    data_start = f.tell()
    j = json.loads(hdr.split(b"\x00", 1)[0].decode("utf-8", "ignore"))
    info = j["files"]["icon.png"]
with open(asar, "rb") as f:
    f.seek(data_start + int(info["offset"]))
    data = f.read(int(info["size"]))
    png_start = data.find(b"\x89PNG")
    if png_start > 0:
        data = data[png_start:]
    open(out, "wb").write(data)
PY

    rm -rf "${install_root}.new"
    mkdir -p "${install_root}.new"
    cp -a "$tmpdir/$top_dir" "${install_root}.new/"
    printf '%s\n' "$version" >"${install_root}.new/.linuxcapable-version"
    if [ -f "${install_root}.new/$top_dir/chrome-sandbox" ]; then
        chown root:root "${install_root}.new/$top_dir/chrome-sandbox"
        chmod 4755 "${install_root}.new/$top_dir/chrome-sandbox"
    fi
    if [ -d "$install_root" ]; then
        rm -rf "${install_root}.previous"
        mv "$install_root" "${install_root}.previous"
    fi
    mv "${install_root}.new" "$install_root"
    ln -sfn "$install_root/$top_dir/antigravity" "$command_link"

    mkdir -p "$(dirname "$icon_file")"
    install -m 0644 "$icon_staged" "$icon_file"
    rm -f "$old_icon_file"

    cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Name=Antigravity
Comment=Google Antigravity 2.0 agent platform
Exec=$command_link %U
Icon=antigravity
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=Antigravity
DESKTOP

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true

    info "Antigravity 2.0 $version installed at $install_root/$top_dir"
}

# ==========================================================================
# Antigravity IDE
# ==========================================================================
install_antigravity_ide() {
    local download_page="https://antigravity.google/download"
    local install_root="/opt/antigravity-ide"
    local command_link="/usr/local/bin/antigravity-ide"
    local desktop_file="/usr/share/applications/antigravity-ide.desktop"
    local icon_file="/usr/share/icons/hicolor/512x512/apps/antigravity-ide.png"
    local archive_top_dir="Antigravity IDE"
    local install_dir="Antigravity-IDE"

    case "$(uname -m)" in
        x86_64 | amd64) platform="linux-x64" ;;
        aarch64 | arm64) platform="linux-arm" ;;
        *) error "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac

    for cmd in curl tar python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "$cmd is required but not installed."; return 1
        fi
    done

    local tmp_parent="${TMPDIR:-/var/tmp}"
    mkdir -p "$tmp_parent"
    local tmpdir=$(mktemp -d "$tmp_parent/antigravity-ide.XXXXXX")
    trap 'rm -rf "$tmpdir"' RETURN
    local download_html="$tmpdir/download.html"
    local download_js="$tmpdir/download.js"
    local archive="$tmpdir/Antigravity-IDE.tar.gz"
    local archive_list="$tmpdir/archive-list.txt"

    info "Fetching Antigravity IDE download page..."
    curl -fsSL --compressed --retry 3 -o "$download_html" "$download_page"

    local main_js_url=$(python3 - "$download_html" "$download_page" <<'PY'
import re, sys
from pathlib import Path
from urllib.parse import urljoin
html = Path(sys.argv[1]).read_text()
page_url = sys.argv[2]
matches = re.findall(r'(?:src|href)="([^"]*main-[^"]+\.js)"', html)
if not matches:
    raise SystemExit("Could not find the Antigravity download bundle")
print(urljoin(page_url, matches[-1]))
PY
)

    curl -fsSL --compressed --retry 3 -o "$download_js" "$main_js_url"

    local download_fields=$(python3 - "$download_js" "$platform" <<'PY'
import re, sys
from pathlib import Path
bundle = Path(sys.argv[1]).read_text(errors="replace")
platform = sys.argv[2]
start = bundle.find('id:"antigravity-ide"')
end = bundle.find('},{name:"download",id:"antigravity-sdk"', start)
if start == -1 or end == -1:
    raise SystemExit("Could not find Antigravity IDE downloads")
section = bundle[start:end]
match = re.search(r'href:"([^"]+/' + re.escape(platform) + r'/Antigravity%20IDE\.tar\.gz)"', section)
if not match:
    raise SystemExit(f"Could not find an IDE download for {platform}")
url = match.group(1)
version_match = re.search(r'/stable/([^/]+)/', url)
if not version_match:
    raise SystemExit("Could not parse IDE version from download URL")
print(version_match.group(1).split("-", 1)[0], url)
PY
)
    read -r version download_url <<<"$download_fields"

    if [ -z "$version" ] || [ -z "$download_url" ]; then
        error "Could not parse the Antigravity IDE download page."; return 1
    fi

    local expected_target="$install_root/$install_dir/antigravity-ide"
    local sandbox_path="$install_root/$install_dir/chrome-sandbox"

    info "Downloading Antigravity IDE $version for $platform..."
    curl -fsSL --retry 3 -o "$archive" "$download_url"
    tar -tzf "$archive" >"$archive_list"
    local top_dir=$(sed -n '1{s#/.*##;p;q}' "$archive_list")
    if [ "$top_dir" != "$archive_top_dir" ]; then
        error "Unexpected archive directory: $top_dir"; return 1
    fi

    tar -xzf "$archive" -C "$tmpdir"
    if [ ! -x "$tmpdir/$archive_top_dir/antigravity-ide" ]; then
        error "The Antigravity IDE launcher was not found."; return 1
    fi

    local icon_source="$tmpdir/$archive_top_dir/resources/app/resources/linux/code.png"
    if [ ! -f "$icon_source" ]; then
        error "The Antigravity IDE icon was not found."; return 1
    fi

    rm -rf "${install_root}.new"
    mkdir -p "${install_root}.new/$install_dir"
    cp -a "$tmpdir/$archive_top_dir/." "${install_root}.new/$install_dir/"
    printf '%s\n' "$version" >"${install_root}.new/.linuxcapable-version"
    if [ -f "${install_root}.new/$install_dir/chrome-sandbox" ]; then
        chown root:root "${install_root}.new/$install_dir/chrome-sandbox"
        chmod 4755 "${install_root}.new/$install_dir/chrome-sandbox"
    fi
    if [ -d "$install_root" ]; then
        rm -rf "${install_root}.previous"
        mv "$install_root" "${install_root}.previous"
    fi
    mv "${install_root}.new" "$install_root"
    ln -sfn "$install_root/$install_dir/antigravity-ide" "$command_link"

    mkdir -p "$(dirname "$icon_file")"
    install -m 0644 "$icon_source" "$icon_file"

    cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity IDE
Exec=$command_link %U
Icon=antigravity-ide
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity-ide;application/x-antigravity-workspace;
StartupNotify=true
StartupWMClass=antigravity-ide
DESKTOP

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true

    info "Antigravity IDE $version installed at $install_root/$install_dir"
}

# ==========================================================================
# Main
# ==========================================================================
echo ""
info "=========================================="
info " Installing Antigravity 2.0 Desktop App..."
info "=========================================="
install_antigravity_hub

echo ""
info "=========================================="
info " Installing Antigravity IDE..."
info "=========================================="
install_antigravity_ide

echo ""
info "=========================================="
info " Installation Complete!"
info "=========================================="
echo ""
echo "  Launch from app menu or terminal:"
echo "    antigravity        (2.0 Desktop App)"
echo "    antigravity-ide    (IDE)"
echo ""
