#!/usr/bin/env bash
#
# TokenScope one-shot installer.
#
# Run it with a single line (no need to clone first):
#   bash <(curl -fsSL https://raw.githubusercontent.com/wmfadzli/orbit-finance-releases/main/TokenScope/install.sh)
#
# What it does, in order:
#   1. Clones/updates the repo into ~/orbit-finance-releases (main branch).
#   2. Prints your token usage from the CLI (needs only Swift — always runs).
#   3. Builds the menu-bar app and launches it (needs Homebrew + Xcode).
#      No Apple Developer account and no code signing required — the app is
#      built unsigned + ad-hoc signed for local use.
#
# It is safe to re-run. If a prerequisite is missing it tells you the one
# command to fix it and exits cleanly (your CLI numbers still print first).

set -uo pipefail

REPO_URL="https://github.com/wmfadzli/orbit-finance-releases.git"
REPO_DIR="${HOME}/orbit-finance-releases"
BRANCH="main"

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m!!  %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31mXX  %s\033[0m\n" "$*"; exit 1; }

# ── 1. Get / update the code ────────────────────────────────────────────────
if [ -d "$REPO_DIR/.git" ]; then
  say "Updating existing checkout at $REPO_DIR"
  git -C "$REPO_DIR" fetch origin "$BRANCH"        || die "git fetch failed"
  git -C "$REPO_DIR" checkout "$BRANCH"             || die "git checkout failed"
  git -C "$REPO_DIR" pull --ff-only origin "$BRANCH" || warn "Couldn't fast-forward; using local copy"
else
  say "Cloning into $REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR" || die "git clone failed"
  git -C "$REPO_DIR" checkout "$BRANCH" >/dev/null 2>&1 || true
fi

APP_DIR="$REPO_DIR/TokenScope"
[ -d "$APP_DIR" ] || die "TokenScope folder not found on '$BRANCH'"

# ── 2. Show the numbers first (only needs Swift) ────────────────────────────
if command -v swift >/dev/null 2>&1; then
  say "Your token usage (parsed from local Claude Code logs):"
  ( cd "$APP_DIR/Packages/UsageCore" && swift run usagescope ) \
    || warn "CLI couldn't run — is the Swift toolchain OK? (xcode-select --install)"
else
  warn "Swift not found. Install Apple's Command Line Tools:  xcode-select --install"
fi

# ── 3. Build the menu-bar app ───────────────────────────────────────────────
say "Now building the menu-bar app (no Apple account needed)…"

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew isn't installed — it's needed to get 'xcodegen'."
  cat <<'EOF'
Install Homebrew with this one line:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
When it finishes it prints a "Next steps" box with two lines to run (they add
'brew' to your PATH) — run those, then re-run this installer.
EOF
  exit 0
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  say "Installing xcodegen via Homebrew"
  brew install xcodegen || die "brew install xcodegen failed"
fi

# xcodebuild needs the full Xcode app, not just the Command Line Tools.
XC_PATH="$(xcode-select -p 2>/dev/null || true)"
if ! printf '%s' "$XC_PATH" | grep -q "Xcode.app"; then
  warn "Building the app needs the full Xcode (currently selected: ${XC_PATH:-none})."
  cat <<'EOF'
  1) Install Xcode from the Mac App Store (free).
  2) Point the tools at it:   sudo xcode-select -s /Applications/Xcode.app
  3) Re-run this installer.
(You can already use the CLI numbers above without Xcode.)
EOF
  exit 0
fi

cd "$APP_DIR"
say "Generating the Xcode project"
xcodegen generate || die "xcodegen failed"

say "Compiling — this can take a minute the first time"
xcodebuild \
  -project TokenScope.xcodeproj \
  -scheme TokenScope \
  -configuration Release \
  -derivedDataPath .build-app \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ENABLE_HARDENED_RUNTIME=NO \
  build || die "Build failed — copy me the last ~20 lines above and I'll fix it."

APP_BUNDLE="$(/usr/bin/find .build-app/Build/Products -maxdepth 2 -name 'TokenScope.app' -print -quit)"
[ -n "$APP_BUNDLE" ] || die "Built app not found under .build-app"

say "Ad-hoc signing for local use"
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || warn "codesign step failed (app may still run)"

DEST="/Applications/TokenScope.app"
say "Installing to $DEST"
if rm -rf "$DEST" 2>/dev/null && cp -R "$APP_BUNDLE" "$DEST" 2>/dev/null; then
  :
else
  warn "Couldn't copy to /Applications; launching from the build folder instead."
  DEST="$APP_BUNDLE"
fi

say "Launching TokenScope — look at the top-right of your menu bar for the gauge + dollar amount!"
open "$DEST"

cat <<'EOF'

Done. TokenScope now lives in your menu bar (it has no Dock icon by design).
Click it for the full Today / Yesterday / Last-30-days breakdown and trend chart.
Re-run this script anytime to update to the latest version.
EOF
