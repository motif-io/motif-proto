# Working in motif-proto

This repository holds the Protobuf schemas for the Motif platform, including the
**component types** that make up Motif models. This guide covers the conventions
an agent (or human) needs to add or change schemas correctly.

Tooling is managed with [`mise`](https://mise.jdx.dev/) (see `.config/mise.toml`)
and [`buf`](https://buf.build/). Run `mise run <task>` for the tasks below.

## Protobuf package names

Schemas are grouped into these top-level packages, all versioned `v1`:

- **`motif.api.v1`** — gRPC service API for the Motif platform.
- **`motif.data.<subpackage>.v1`** — Component types defined by Motif, grouped by
  subpackage (e.g. `motif.data.core.v1`, `motif.data.model.v1`).
- **`motif.event.v1`** — Message types for notification events.
- **`motif.extension.v1`** — Custom Protobuf options and types used to extend the
  platform with new component types.
- **`thirdparty.<partner>.data.<domain>.v1`** — Partner-owned component types
  (e.g. `thirdparty.bhom.data.physical.v1`), under `proto/thirdparty/…` so they
  sort after `motif` on the Buf Schema Registry.

### Public vs internal gRPC services in `motif.api.v1`

Not every service in `motif.api.v1` is a public client API.

- **`Persistence`** — public model/changeset API (browser / Raven / grpc-web and
  native gRPC). End-user Bearer auth is enforced per RPC.
- **`InternalPersistence`** — control-plane → persistence **service-to-service**
  API (e.g. shallow model copy). Deployments must register it only on the mTLS
  S2S listener, never on the public Persistence listener. Control-plane owns
  end-user authorization; persistence trusts authenticated internal callers.

Do **not** add orchestration / privileged copy / admin RPCs to `Persistence`.
Put them on `InternalPersistence` (or another explicitly internal service) so
public clients cannot invoke them directly.

A file's package must match its path under `proto/`: a file in package
`motif.data.core.v1` lives at `proto/motif/data/core/v1/<file>.proto`. Imports use
the module-root-relative path, e.g. `import "motif/extension/v1/options.proto";`.

### Component types always live in `motif.data.<subpackage>.v1`

Every Motif component type **must** be defined in a `motif.data.<subpackage>.v1`
package. Pick the subpackage that fits the domain (e.g. `core`, `model`, `view`,
`style`, `fde`) or add a new `motif.data.<new>.v1` subpackage if none fits. Do
**not** define component types in `motif.api.v1`, `motif.event.v1`, or
`motif.extension.v1`. Partner types use `thirdparty.<partner>.data.<domain>.v1`
instead of living under `motif.data.*`.

## Defining a Motif component type

A component type is a message marked with the custom message option
`option (motif.extension.v1.message).component`, whose value is the component's
unique integer ID. The option is defined in
`proto/motif/extension/v1/options.proto`.

To define one:

1. Work in a file under the correct `motif.data.<subpackage>.v1` package (see
   above).
2. Import the options schema: `import "motif/extension/v1/options.proto";`.
3. Get the next available ID with `mise run next-id` (see below).
4. Add the option as the first line of the message body, then the fields.

```proto
syntax = "proto3";

package motif.data.core.v1;

import "motif/extension/v1/options.proto";

// A user-visible name for an entity that was explicitly set by a user.
message AssignedName {
  option (motif.extension.v1.message).component = 2;

  // The user-assigned name.
  string name = 1;
}
```

There is also a field option, `option (motif.extension.v1.field).data_reference_expected_type`,
which should be set on every `DataReference` field to declare its expected type.

## Well-known reference types

Relationship and representation targets are discovered **structurally** by
message type from `motif/extension/v1/reference.proto`, not by field options:

- `EntityReference` — target entity UUID
- `ModelReference` — target model UUID + version
- `DataReference` — typed data on an entity (plus `data_reference_expected_type`)
- `RepresentationReference` — representation blob UUID

Component fields that carry representation IDs must use
`motif.extension.v1.RepresentationReference` so copy/manifest tooling can
rewrite those UUIDs without touching unrelated bytes. Prefer this type for new
fields.

The existing raw `bytes` representation IDs —
`motif.data.core.v1.Representation.id` (component 4) and
`motif.data.core.v1.ThumbnailRepresentation.id` (component 40) — must be
migrated to `RepresentationReference` before structural discovery finds
anything in real models. Reusing the same field number changes the field from
raw 16 bytes to an encoded submessage, so this is an intentional wire break:
land it in a dedicated PR labelled `buf skip breaking`, coordinated with a
data-service-v2 stored-bytes migration (or a decode-time shim). It is out of
scope for the additive PROTO-1 contract.

## Choosing the component ID

Component IDs are **globally unique across the entire repository** — not per file
or per package — and gaps from removed types are **never reused** (the next ID is
always the highest ever assigned, plus one). A `buf` lint rule fails the build if
two component types share an ID.

To find the ID to use for a new component, run:

```sh
mise run next-id
```

This prints one more than the highest `component` ID currently assigned anywhere
in the schemas (it reads the compiled descriptor, so it includes nested
messages).

Keep IDs dense: prefer the value from `mise run next-id` over assigning IDs far
from the sequence. `mise run check-id-gaps` (part of `mise run lint`, and run in
CI) fails if more than 10 consecutive IDs are left unused between two assigned
IDs — a guard against typos like `600` for `60`.

## After making changes

Format, then run the full lint suite (the same checks CI runs, including the
`MOTIF` duplicate-ID rule):

```sh
mise run format   # buf format -w + taplo fmt
mise run lint     # buf format check, buf lint, buf breaking, taplo check, ID-gap check
```

`mise run lint` runs `buf breaking` against `origin/main`, so make sure your
local `main` ref is up to date for accurate results.