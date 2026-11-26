#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Writes the .env file for ONE server, for a CI build.
#
#   bash ci/scripts/create_env_files.sh <dev|staging|prod>
#
# Every build is the same app (org.pecha.app, flavor prod). The server it talks
# to is picked by the entry file, which loads the matching .env file:
#
#   server   entry file               .env file      WeBuddhist API / library
#   dev      lib/main_dev.dart        .env.dev       dev.api      / dev.library
#   staging  lib/main_staging.dart    .env.staging   test.api     / testing.library
#   prod     lib/main_prod.dart       .env.prod      api          / library-prod
#
# ("staging" is the name of the TESTING server's files and secrets.)
#
# The server URLs are written here, not read from secrets: they are public (any
# copy of the app contains them), and a secret's value cannot be read back, so a
# stale URL secret goes unnoticed. Only the keys come from secrets, named with
# the server's prefix: DEV_*, STAGING_*, or no prefix for prod.
#
# pubspec.yaml lists all three .env files as assets, so all three must exist,
# but only the chosen server's file gets values. The other two are placeholders,
# so a build never carries another server's keys.
# ---------------------------------------------------------------------------
set -euo pipefail

server="${1:-}"

case "$server" in
  dev)
    prefix="DEV_"
    environment="development"
    base_api_url="https://dev.api.webuddhist.com/api/v1"
    library_api_url="https://dev.library.webuddhist.com/api"
    ;;
  staging)
    prefix="STAGING_"
    environment="staging"
    base_api_url="https://test.api.webuddhist.com/api/v1"
    library_api_url="https://testing.library.webuddhist.com/api"
    ;;
  prod)
    prefix=""
    environment="production"
    base_api_url="https://api.webuddhist.com/api/v1"
    # The prod library does not serve /api yet (/api/v2/texts answers 404).
    library_api_url="https://library-prod.webuddhist.com"
    ;;
  *)
    echo "::error::Usage: create_env_files.sh <dev|staging|prod> (got '${server}')"
    exit 1
    ;;
esac

# Reads the secret <prefix><name> from the environment ("" when unset).
secret() {
  local name="${prefix}$1"
  printf '%s' "${!name:-}"
}

library_api_key="$(secret LIBRARY_API_KEY)"
chants_tag_id="$(secret LIBRARY_CHANTS_TAG_ID)"

# The testing library is a copy of prod data, so it has the same tag IDs.
if [[ -z "$chants_tag_id" && "$server" == "staging" ]]; then
  chants_tag_id="${LIBRARY_CHANTS_TAG_ID:-}"
  [[ -n "$chants_tag_id" ]] &&
    echo "::notice::STAGING_LIBRARY_CHANTS_TAG_ID is not set; using the prod chants tag (testing is a copy of prod)."
fi

# Each library rejects calls without its own key, and the chant list cannot
# load without its tag, so a build without them would ship broken. Fail here.
missing=()
[[ -z "$library_api_key" ]] && missing+=("${prefix}LIBRARY_API_KEY")
[[ -z "$chants_tag_id" ]] && missing+=("${prefix}LIBRARY_CHANTS_TAG_ID")
if (( ${#missing[@]} > 0 )); then
  echo "::error::Missing secrets for the ${server} server: ${missing[*]}"
  exit 1
fi

# --- The chosen server's file ------------------------------------------------
{
  echo "BASE_API_URL=${base_api_url}"
  echo "LIBRARY_API_URL=${library_api_url}"
  echo "LIBRARY_CHANTS_TAG_ID=${chants_tag_id}"
  echo "LIBRARY_API_KEY=${library_api_key}"
  # One app for every server, so one URL scheme.
  echo "AUTH0_SCHEME=org.pecha.app"
  echo "AUTH0_AUDIENCE=$(secret AUTH0_AUDIENCE)"
  echo "ENVIRONMENT=${environment}"
  # PostHog stays off while the key is empty.
  echo "POSTHOG_API_KEY=$(secret POSTHOG_API_KEY)"
  echo "POSTHOG_HOST=${POSTHOG_HOST:-https://us.i.posthog.com}"
  # Clarity project id is a public identifier, not a secret. Sessions carry an
  # `environment` tag, so one project serves every server.
  echo "CLARITY_PROJECT_ID=${CLARITY_PROJECT_ID-yn5na4zbuc}"
  echo "CLARITY_ENABLED=$(secret CLARITY_ENABLED)"
  # Venue search; it is hidden while the key is empty.
  echo "LOCATIONIQ_TOKEN=${LOCATIONIQ_TOKEN:-}"
} > ".env.${server}"

# --- Placeholders for the other two servers ----------------------------------
for other in dev staging prod; do
  [[ "$other" == "$server" ]] && continue
  echo "# Not used: this build talks to the ${server} server." > ".env.${other}"
done

# Only names and URLs go to the log, never key values.
set_or_empty() { [[ -n "$1" ]] && echo "set" || echo "empty"; }
summary="$(cat <<EOF
### Server: ${server}

| Setting | Value |
| --- | --- |
| Entry file | \`lib/main_${server}.dart\` |
| WeBuddhist API | ${base_api_url} |
| Library API | ${library_api_url} |
| Library key (\`${prefix}LIBRARY_API_KEY\`) | set |
| PostHog key (\`${prefix}POSTHOG_API_KEY\`) | $(set_or_empty "$(secret POSTHOG_API_KEY)") |
EOF
)"
echo "$summary"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "$summary" >> "$GITHUB_STEP_SUMMARY"
fi
