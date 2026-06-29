#!/usr/bin/env bash
# Fail if any two consecutive Motif component type IDs are separated by more than
# <max-gap> unused IDs. Component IDs are never reused, so a large gap is
# permanently wasted ID space — usually a typo or an ID assigned far from the
# sequence. Use `mise run next-id` to pick the next ID in sequence.
#
# Reads IDs from the compiled descriptor (not text), so nested messages are
# included. Component IDs are spread across many .proto files under proto/.
#
# Usage: tools/check-component-id-gaps.sh <max-gap>   (or: mise run check-id-gaps)
set -euo pipefail

max_gap="${1:-}"
if [[ ! "$max_gap" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <max-gap>" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

offenders=$(
  buf build -o '-#format=json' \
    | jq -r --argjson max "$max_gap" '
        [ .. | objects
          | select(has("[motif.extension.v1.message]"))
          | .["[motif.extension.v1.message]"].component // empty ]
        | unique
        | . as $ids
        | [ range(1; length)
            | { lo: $ids[.-1], hi: $ids[.], gap: ($ids[.] - $ids[.-1] - 1) }
            | select(.gap > $max) ]
        | .[]
        | "  gap of \(.gap) between component IDs \(.lo) and \(.hi)"'
)

if [[ -n "$offenders" ]]; then
  echo "Component ID gaps larger than $max_gap found:" >&2
  echo "$offenders" >&2
  exit 1
fi

echo "No component ID gaps larger than $max_gap."
