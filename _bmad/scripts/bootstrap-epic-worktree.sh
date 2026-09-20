#!/usr/bin/env bash
# Give an epic worktree what git does not: the client's dependencies and the read-only IRIS
# reference trees. Run by the orchestrator right after new-epic-worktree.sh reports PROVISIONED
# and before the runner is spawned (OcuPilot project Rule 25). Idempotent.
#
#   ui/node_modules            -- `npm ci` from ui/package-lock.json (gitignored, ~300 MB per worktree)
#   irislib irissys irisui irisdocs -- symlinks to the main checkout's exports (gitignored, read-only
#                                 reference material; nothing writes them, so sharing is safe)
#
# usage: bash _bmad/scripts/bootstrap-epic-worktree.sh <worktree-path> [main-checkout-path]
set -euo pipefail
WT="${1:?usage: bootstrap-epic-worktree.sh <worktree-path> [main-checkout-path]}"
MAIN="${2:-$(git rev-parse --show-toplevel)}"
[ -d "$WT/ui" ] || { echo "ERROR: $WT has no ui/ -- not an OcuPilot worktree" >&2; exit 1; }
[ "$(cd "$WT" && git rev-parse --show-toplevel)" != "$(cd "$MAIN" && git rev-parse --show-toplevel)" ] \
  || { echo "ERROR: $WT is the main checkout, not a worktree" >&2; exit 1; }

for ref in irislib irissys irisui irisdocs; do
  if [ -e "$WT/$ref" ] && [ ! -L "$WT/$ref" ]; then echo "SKIP $ref: a real directory exists in the worktree"; continue; fi
  if [ -d "$MAIN/$ref" ]; then ln -sfn "$MAIN/$ref" "$WT/$ref"; echo "LINKED $ref -> $MAIN/$ref"
  else echo "ABSENT $ref in the main checkout (reference tree not exported; agents fall back to the instance)"; fi
done

# A symlinked ui/node_modules (seen on the epic-13 worktree, 2026-09-19) passes the stamp check
# through the link and shows as untracked to git, since .gitignore's trailing-slash pattern matches
# directories only. Replace it with a real install.
if [ -L "$WT/ui/node_modules" ]; then
  rm "$WT/ui/node_modules"; echo "REMOVED symlinked ui/node_modules (a worktree needs its own install)"
fi
STAMP="$WT/ui/node_modules/.ocupilot-bootstrap.sha"
WANT="$(shasum -a 256 "$WT/ui/package-lock.json" | cut -d' ' -f1)"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT" ]; then
  echo "OK ui/node_modules already matches package-lock.json"
else
  echo "npm ci in $WT/ui ..."
  # The browser harness launches the full Chrome build (browser.config.mjs: headless: true), which puppeteer
  # caches once under ~/.cache/puppeteer and shares across checkouts; the separate chrome-headless-shell
  # download is not used here, so skip it rather than pay for it per worktree.
  ( cd "$WT/ui" && PUPPETEER_SKIP_CHROME_HEADLESS_SHELL_DOWNLOAD=1 npm ci --no-audit --no-fund --loglevel=error )
  printf '%s\n' "$WANT" > "$STAMP"
  echo "OK ui/node_modules installed"
fi
# The bootstrap must leave the worktree clean: everything it created is gitignored.
DIRT="$(cd "$WT" && git status --short)"
[ -z "$DIRT" ] || { echo "ERROR: bootstrap left the worktree dirty:" >&2; echo "$DIRT" >&2; exit 1; }
echo "BOOTSTRAPPED worktree=$WT"
