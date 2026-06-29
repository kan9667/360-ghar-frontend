#!/usr/bin/env bash
#
# Netlify build script for the ghar360 Flutter web app.
#
# Netlify's build image has no Flutter SDK, so we install a pinned version,
# generate .env.production from Netlify environment variables, then build the
# release web bundle into build/web (the publish dir in netlify.toml).
#
# Configure secrets in: Netlify dashboard -> Site configuration ->
# Environment variables (scoped to Production and Deploy previews).

set -euo pipefail

# Keep this in sync with .fvmrc and .github/workflows/build.yml.
FLUTTER_VERSION="3.35.2"

# Cache the SDK between builds when Netlify exposes a persistent cache dir.
CACHE_DIR="${NETLIFY_BUILD_BASE:-$HOME}/cache"
FLUTTER_DIR="${CACHE_DIR}/flutter"

# ---------------------------------------------------------------------------
# 1. Install Flutter (pinned). Reuse the cached SDK if it is the right version.
# ---------------------------------------------------------------------------
mkdir -p "${CACHE_DIR}"

needs_install=true
if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
  cached_version="$("${FLUTTER_DIR}/bin/flutter" --version 2>/dev/null | head -n1 || true)"
  if echo "${cached_version}" | grep -q "${FLUTTER_VERSION}"; then
    echo "Using cached Flutter ${FLUTTER_VERSION}"
    needs_install=false
  else
    echo "Cached Flutter is stale (${cached_version}); reinstalling"
    rm -rf "${FLUTTER_DIR}"
  fi
fi

if [ "${needs_install}" = true ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  TARBALL="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${TARBALL}"
  curl -fsSL --retry 3 -o "${CACHE_DIR}/${TARBALL}" "${URL}"
  tar -xf "${CACHE_DIR}/${TARBALL}" -C "${CACHE_DIR}"
  rm -f "${CACHE_DIR}/${TARBALL}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

# Mark the SDK dir safe for git (Flutter runs git internally).
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version
flutter config --enable-web
flutter precache --web

# ---------------------------------------------------------------------------
# 2. Generate the .env files from Netlify environment variables.
#    The real .env.* files are gitignored (only the .example files are
#    committed), so they do NOT exist in the Netlify checkout. pubspec.yaml
#    lists BOTH .env.development and .env.production as assets, so both must
#    be written or `flutter build web` fails on the missing asset.
#    The web build is --release, so .env.production is what loads at runtime;
#    .env.development is written with identical content (matching build.yml).
#    Do NOT print the file contents — avoid leaking secrets into logs.
# ---------------------------------------------------------------------------
: "${SUPABASE_URL:?SUPABASE_URL is required (set it in Netlify env vars)}"
: "${SUPABASE_PUBLISHABLE_KEY:?SUPABASE_PUBLISHABLE_KEY is required (set it in Netlify env vars)}"

for ENV_FILE in .env.development .env.production; do
  cat > "${ENV_FILE}" <<EOF
# Generated at Netlify build time from environment variables. Do not commit.

# Supabase (required)
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}

# API + integrations
API_BASE_URL=${API_BASE_URL:-}
GOOGLE_PLACES_API_KEY=${GOOGLE_PLACES_API_KEY:-}
GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID:-}
GOOGLE_IOS_CLIENT_ID=

# App configuration
DEFAULT_COUNTRY=${DEFAULT_COUNTRY:-in}
DEBUG_MODE=${DEBUG_MODE:-false}
LOG_API_CALLS=${LOG_API_CALLS:-false}

# PostHog
POSTHOG_API_KEY=${POSTHOG_API_KEY:-}
POSTHOG_HOST=${POSTHOG_HOST:-https://us.i.posthog.com}

# Firebase (default off for web unless a Firebase web config is wired up)
FIREBASE_ENABLED=${FIREBASE_ENABLED:-false}
FIREBASE_CRASHLYTICS=${FIREBASE_CRASHLYTICS:-false}
FIREBASE_ANALYTICS=${FIREBASE_ANALYTICS:-false}
FIREBASE_PERFORMANCE=${FIREBASE_PERFORMANCE:-false}
FIREBASE_IAM=${FIREBASE_IAM:-false}

# Build metadata
BUILD_ENV=netlify
COMMIT_SHA=${COMMIT_REF:-}
BRANCH_NAME=${BRANCH:-}
EOF
  echo "Wrote ${ENV_FILE} ($(wc -l < "${ENV_FILE}") lines)"
done

# ---------------------------------------------------------------------------
# 3. Build the release web bundle. Generated *.g.dart files are committed,
#    so build_runner is not needed.
# ---------------------------------------------------------------------------
flutter pub get
flutter build web --release --base-href=/

echo "Web build complete: build/web"
