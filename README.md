# motif-proto

Protobuf schemas for the Motif platform.

## Layout

Everything lives in a single [buf v2 module](https://buf.build/docs/configuration/v2/buf-yaml)
rooted at `proto/`. Files live in the directory that mirrors their package name,
relative to that root — e.g. package `motif.extension.v1` is at
`proto/motif/extension/v1/`, and `motif.data.ai.v1` is at
`proto/motif/data/ai/v1/`.

Partner-owned types use packages under `thirdparty.<partner>.data.<domain>.v1`
(e.g. `thirdparty.bhom.data.base.v1` at `proto/thirdparty/bhom/data/base/v1/`) so
they sort after `motif` on the Buf Schema Registry and stay out of the top-level
partner namespace.

One module (rather than one per package) keeps the schemas on a single buf
repository. Add a new package by creating its package-mirrored directory under
`proto/` (e.g. `proto/motif/data/<area>/v1/`) — no `buf.yaml` change is
required.

## Custom options

Motif extends protobuf with its own message and field options, defined in
[`proto/motif/extension/v1/options.proto`](proto/motif/extension/v1/options.proto).
See that file for the full set; this section covers how to apply them.

Mark a message as a component type and assign its ID with the `component` message
option (see [Choosing a component ID](#choosing-a-component-id)):

```proto
message DefaultName {
  option (motif.extension.v1.message).component = 1;

  string name = 1;
}
```

Declare the type a `DataReference` field resolves to with the
`data_reference_expected_type` field option — set it on every `DataReference`
field:

```proto
motif.extension.v1.DataReference curve = 3 [
  (motif.extension.v1.field).data_reference_expected_type = {
    kind: TYPE_MESSAGE
    type_name: "motif.data.geometry.v1.Curve2"
  }
];
```

Representation blob IDs use the well-known
`motif.extension.v1.RepresentationReference` message (same structural discovery
pattern as `EntityReference` / `ModelReference`):

```proto
motif.extension.v1.RepresentationReference representation = 1 [
  (buf.validate.field).required = true
];
```

## Choosing a component ID

Component IDs (the value of `option (motif.extension.v1.message).component`) are
unique across the whole repository, and IDs from removed types are never reused.
A buf lint rule fails the build if two component types share an ID.

To find the next available ID — one more than the highest currently assigned —
run:

```sh
mise run next-id
```

Keep IDs dense: prefer the value from `mise run next-id` over assigning IDs far
from the sequence. CI runs `mise run check-id-gaps`, which fails if more than 10
consecutive IDs are left unused between two assigned IDs (a guard against typos
like `600` for `60`).
