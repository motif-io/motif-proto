# Print the next available Motif component type ID: one more than the highest
# `option (motif.extension.v1.message).component` assigned across the schemas.
#
# Reads the compiled descriptor JSON on stdin (`buf build -o -#format=json`), so
# nested messages are included. Component IDs are spread across many .proto files
# under proto/. Run via `mise run next-id`.
#
# IDs in the range reserved for model-defined types (2147473648 and up)
# are skipped, so a type under development in a model does not move the next
# platform ID into that range.
[
  ..
  | objects
  | select(has("[motif.extension.v1.message]"))
  | .["[motif.extension.v1.message]"].component // empty
  | select(. < 2147473648)
]
| (max // 0) + 1