# Print the next available Motif component type ID: one more than the highest
# `option (motif.extension.v1.message).component` assigned across the schemas.
#
# Reads the compiled descriptor JSON on stdin (`buf build -o -#format=json`), so
# nested messages are included. Component IDs are spread across many .proto files
# under proto/. Run via `mise run next-id`.
[
  ..
  | objects
  | select(has("[motif.extension.v1.message]"))
  | .["[motif.extension.v1.message]"].component // empty
]
| (max // 0) + 1