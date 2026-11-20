# Fail if any two consecutive Motif component type IDs are separated by more than
# $max unused IDs. Component IDs are never reused, so a large gap is permanently
# wasted ID space — usually a typo or an ID assigned far from the sequence. Use
# `mise run next-id` to pick the next ID in sequence.
#
# Reads the compiled descriptor JSON on stdin (`buf build -o -#format=json`), so
# nested messages are included. Pass the threshold with `jq --argjson max <N>`.
# Run via `mise run check-id-gaps`.
#
# IDs in the range reserved for model-defined types (2147473648 and up) are left
# out, so the gap below that range isn't counted; `mise run check-reserved-ids`
# reports any type that uses one.
[
  ..
  | objects
  | select(has("[motif.extension.v1.message]"))
  | .["[motif.extension.v1.message]"].component // empty
  | select(. < 2147473648)
]
| unique
| . as $ids
| [
    range(1; length)
    | { lo: $ids[. - 1], hi: $ids[.], gap: ($ids[.] - $ids[. - 1] - 1) }
    | select(.gap > $max)
  ] as $offenders
| if ($offenders | length) > 0
  then
    (
      "Component ID gaps larger than \($max) found:\n"
      + ($offenders
         | map("  gap of \(.gap) between component IDs \(.lo) and \(.hi)")
         | join("\n"))
      + "\n"
    )
    | halt_error(1)
  else
    "No component ID gaps larger than \($max)."
  end