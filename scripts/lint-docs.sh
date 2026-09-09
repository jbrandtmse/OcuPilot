#!/usr/bin/env bash
#
# Run both markdown checks over OcuPilot's authored documents.
#
#   bash scripts/lint-docs.sh          report problems
#   bash scripts/lint-docs.sh --fix    repair what markdownlint can repair
#
# The document set is defined once, in scripts/check-prose.py (DEFAULT_GLOBS);
# this script asks that script for the list. .markdownlint-cli2.jsonc carries
# the rules and nothing else -- see the note at the top of it for why.
set -o pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

FIX=""
[ "${1:-}" = "--fix" ] && FIX="--fix"

FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && FILES+=("$f")
done < <(uv run scripts/check-prose.py --list)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "lint-docs: no documents matched" >&2
  exit 1
fi

STATUS=0
npx --yes markdownlint-cli2 $FIX -- "${FILES[@]}" || STATUS=1
uv run scripts/check-prose.py || STATUS=1

exit $STATUS
