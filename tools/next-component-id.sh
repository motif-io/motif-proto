#!/usr/bin/env bash
# Print the next available Motif component type ID: one more than the highest
# `option (motif.extension.v1.message).component` assigned across the schemas.
#
# Reads IDs from the compiled descriptor (not text), so nested messages are
# included. Component IDs are spread across many .proto files under proto/.
#
# Usage: tools/next-component-id.sh   (or: mise run next-id)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

buf build -o '-#format=json' \
  | jq '[ .. | objects
          | select(has("[motif.extension.v1.message]"))
          | .["[motif.extension.v1.message]"].component // empty ]
        | (max // 0) + 1'
