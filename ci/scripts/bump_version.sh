#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Auto-bumps the semantic version (the "X.Y.Z" version name) in pubspec.yaml
# based on the Conventional Commits / branch names landed since the last
# release tag. Falls back to a PATCH bump when no convention is detected.
#
#   major (X+1.0.0) : a commit "<type>!:" or a "BREAKING CHANGE" footer,
#                     or a branch named  breaking/*  or  major/*
#   minor (X.Y+1.0) : a "feat:"/"feat(scope):" commit,
#                     or a branch named  feat/*  or  feature/*
#   patch (X.Y.Z+1) : anything else (fix, chore, docs, refactor, …) and the
#                     fallback when no convention is present at all
#
# The "+build" metadata is preserved as-is — CI sets the real, monotonic build
# number at build time (github.run_number + offset), so pubspec's build value
# is only a placeholder.
#
# The script only computes + writes pubspec.yaml; release-prod.yml commits it
# back on every push to main, where the testing build is made.
#
# The next version is counted from the last RELEASE tag (vX.Y.Z, pushed by hand
# to ship to the stores), not from pubspec. Several merges to main before a
# release therefore keep the same pending version (e.g. 2.48.0) instead of
# bumping again each time; it only moves up when a bigger change lands (a feat
# after only fixes, or a breaking change). pubspec still wins if someone set it
# higher by hand.
#
# Outputs (when $GITHUB_OUTPUT is set, i.e. on CI):
#   version_name=<new X.Y.Z>   level=<major|minor|patch>   version=<X.Y.Z+build>
# ---------------------------------------------------------------------------
set -euo pipefail

PUBSPEC="${PUBSPEC_PATH:-pubspec.yaml}"

# --- current version -------------------------------------------------------
current_line="$(grep -E '^version:' "$PUBSPEC" | head -n1)"
current="${current_line#version:}"
current="${current// /}"                       # strip spaces -> "X.Y.Z+build"
name="${current%%+*}"                           # "X.Y.Z"
build=""
[ "$current" != "$name" ] && build="${current#*+}"   # "build" (empty if no +)

# Prints the higher of two X.Y.Z versions.
max_version() {
  printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1
}

# --- version to bump FROM --------------------------------------------------
# The highest "v*" tag: the last version released (older tags carry a
# "-build-N" suffix, which is dropped). pubspec is only the base before any tag.
tag_ver="$(git tag -l 'v*' 2>/dev/null | sed -E 's/^v//; s/-.*$//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1 || true)"
base="${tag_ver:-$name}"

IFS='.' read -r major minor patch <<<"$base"
: "${major:=0}" "${minor:=0}" "${patch:=0}"

# --- commit range whose messages decide the bump LEVEL (since last release) -
last_tag="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
if [ -n "$last_tag" ]; then
  range="${last_tag}..HEAD"
else
  range="HEAD"                                   # no tags yet: inspect all history
fi

subjects="$(git log --format='%s' "$range" 2>/dev/null || true)"
bodies="$(git log --format='%b' "$range" 2>/dev/null || true)"
# Branch name behind each merge commit, e.g. "Merge pull request #1 from org/feat/x" -> "feat/x"
branches="$(git log --merges --format='%s' "$range" 2>/dev/null | sed -nE 's/.*from [^/]+\/(.+)$/\1/p' || true)"

# --- decide the bump level (highest wins) ----------------------------------
level="patch"

if printf '%s\n' "$subjects" | grep -qiE '^[[:space:]]*(feat|feature)(\([^)]+\))?!?:' \
   || printf '%s\n' "$branches" | grep -qiE '^(feat|feature)/'; then
  level="minor"
fi

if printf '%s\n' "$subjects" | grep -qE '^[[:space:]]*[a-z]+(\([^)]+\))?!:' \
   || printf '%s\n' "$bodies"   | grep -qE '^[[:space:]]*BREAKING[ -]CHANGE:' \
   || printf '%s\n' "$branches" | grep -qiE '^(breaking|major)/'; then
  level="major"
fi

case "$level" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

# Never go below pubspec: it already holds the pending version after an
# earlier merge, or a version someone set by hand.
new_name="$(max_version "${major}.${minor}.${patch}" "$name")"
new_version="$new_name"
[ -n "$build" ] && new_version="${new_name}+${build}"

# --- rewrite the top-level version line in pubspec.yaml --------------------
NEW_VERSION="$new_version" perl -i -pe 'if (!$done && /^version:/) { $_ = "version: $ENV{NEW_VERSION}\n"; $done = 1 }' "$PUBSPEC"

echo "Last release tag : ${last_tag:-<none>}"
echo "Base version     : $base   (pubspec=$name, highest tag=${tag_ver:-<none>})"
echo "Bump level       : $level"
echo "New version      : $new_version"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version_name=$new_name"
    echo "version=$new_version"
    echo "level=$level"
  } >>"$GITHUB_OUTPUT"
fi
