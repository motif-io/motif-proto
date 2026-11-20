# Fail if any Motif component type uses an ID in the range reserved for types a
# model defines for its own use (2147473648 and up). Such a type is under
# development in a model, in a local checkout, and must not be committed (see
# CONTRIBUTING.md "Developing a Component Type in a Model").
#
# Reads the compiled descriptor JSON on stdin (`buf build -o -#format=json`), so
# nested messages are included. Run via `mise run check-reserved-ids`.

# Each message in a `messageType` array, nested ones included, with its full
# name and component ID.
def messages($scope):
  .[]?
  | ($scope + "." + .name) as $name
  | { name: $name, id: (.options["[motif.extension.v1.message]"].component // null) },
    (.nestedType | messages($name));

[
  .file[]
  | . as $file
  | .messageType
  | messages($file.package // "")
  | select(.id != null and .id >= 2147473648)
  | . + { file: $file.name }
]
| sort_by(.id)
| if length > 0
  then
    (
      "Component IDs 2147473648 and up are reserved for types developed in a model,\n"
      + "which must not be committed:\n"
      + (map("  \(.id) \(.name | ltrimstr(".")) (\(.file))") | join("\n"))
      + "\n"
    )
    | halt_error(1)
  else
    "No component types use reserved IDs."
  end
