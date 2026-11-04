# Contributing to motif-proto

The Motif platform uses an extensible data model, with Protobuf being used
to define "components" as structured data attached to an entity. Contributors
to this repo can define new component types, and use them to write data into
a model in Motif.

## Adding a Package for Your Organization

Contributors define a Protobuf package that will contain their component type
definitions. This package **must** be created within the `proto/thirdparty`
directory, and have the form `thirdparty.<org>.data.<domain>.<version>`.

For example:

| Package                              | Directory                                  |
| ------------------------------------ | ------------------------------------------ |
| `thirdparty.acme.data.base.v1`       | `proto/thirdparty/acme/data/base/v1/`      |
| `thirdparty.acme.data.structure.v1`  | `proto/thirdparty/acme/data/structure/v1/` |

* Use a short, lowercase, stable identifier for `<org>`
* Use `<domain>` to define logical groupings of component types
* Increment `<version>` to define new major versions of your package

## Choosing a Component ID

A component is a Protobuf message type marked with the
[component message option](https://buf.build/motif/platform/docs/main%3Amotif.extension.v1#motif.extension.v1.MotifMessageOptions).
This option defines the component ID, which is a globally unique number
that identifies the component within the Motif platform. This repository
coordinates the assignment of these IDs and enforces uniqueness prior to
merges on the `main` branch.

Import the options schema and set the option as the first line of the
message body:

```proto
syntax = "proto3";

package thirdparty.acme.data.structure.v1;

import "motif/extension/v1/options.proto";

// The fire-resistance rating assigned to a structural element.
message FireRating {
  option (motif.extension.v1.message).component = 226;

  // Minimum duration the element withstands a standard fire test, in minutes.
  uint32 duration_minutes = 1;
}
```

To find the next available component ID, run:

```sh
mise run next-id
```

Note that this returns the next available ID based on the current state
of your local working tree. Prior to merging, you may need to renumber
your component IDs based on the current state of `main` due to conflicting
component IDs merged by other contributors. Your pull request will not be
accepted until such conflicts are resolved.

### Once Merged, an ID Is Permanent

After a component type merges, its ID is part of persisted model data. Both
removing an ID and moving one to a different type are breaking changes, and
`buf breaking` rejects them.

## The Onboarding Pull Request

Your organization's first pull request establishes the package and its
ownership:

1. Create the package directory and at least one `.proto` file in it.
2. In your package comment, provide an overview of your package and how
   to use it.
3. In your PR description, provide the full name and website of your
   organization.
4. Add your ownership entry to [`.github/CODEOWNERS`](.github/CODEOWNERS), below
   the existing `/proto/thirdparty/` line. Specify the GitHub users that
   will own the package.

```
/proto/thirdparty/acme/ @acme-alice @acme-bob
```

Two constraints on that entry:

- **Owners must have write access.** Motif grants your listed accounts outside
  collaborator access as part of approving this PR; until then the entry has no
  effect.
- **A GitHub team from another organization cannot be a code owner.** List owners
  as individual accounts, rather than teams from your GitHub organization.

List at least two identities where you can. A single owner blocks all review of
your package whenever that person is unavailable.

### Review

The Motif team reviews this initial PR. Once it merges, your CODEOWNERS entry
takes effect and subsequent PRs touching only your package are reviewed by your
own owners. Changes to Motif-owned packages, shared options, or tooling still
require Motif review.

## Component Guidelines

### References

A component that points at other data **must** use the reference types in
`motif/extension/v1/reference.proto`, never raw `bytes` or `string` IDs. The
platform finds and rewrites references by these types, for example when
entities are copied between models. An ID stored as plain bytes looks like any
other data, so it silently goes stale when that happens.

```proto
syntax = "proto3";

package thirdparty.acme.data.structure.v1;

import "buf/validate/validate.proto";
import "motif/extension/v1/options.proto";
import "motif/extension/v1/reference.proto";

// A bolted connection between two structural members.
message BoltedConnection {
  option (motif.extension.v1.message).component = 227;

  // The member the connection is attached to.
  motif.extension.v1.EntityReference primary_member = 1 [(buf.validate.field).required = true];

  // The member attached to the primary member.
  motif.extension.v1.EntityReference secondary_member = 2 [(buf.validate.field).required = true];

  // The model containing both members. Unset when they are in this model.
  motif.extension.v1.ModelReference model = 3;

  // The design load the connection is sized for, in kilonewtons.
  motif.extension.v1.DataReference design_load = 4 [
    (buf.validate.field).required = true,
    (motif.extension.v1.field).data_reference_expected_type = {kind: TYPE_DOUBLE}
  ];
}
```

See the
[`motif.extension.v1` package docs](https://buf.build/motif/platform/docs/main%3Amotif.extension.v1)
for more information about each reference type.

**References are fixed once merged.** The `MOTIF` breaking rules reject adding a
field that can carry a reference to an existing component type (or to a
message it contains), retyping a field so that it can, and changing or removing
a `DataReference` field's expected type. Decide a component's references before
it merges; to add one later, define a new component type.

### Deprecating Message Types and Fields

`buf breaking` runs on every pull request with the `FILE` and `MOTIF` rule sets,
comparing against the base branch. Published schemas cannot make breaking
changes, including removal of existing message types and fields.

**Never** change the meaning of a field number, change a field's type, renumber
a field, or reuse a field number or enum number for a different purpose.

**To retire a message type or field**, mark it deprecated and point readers at
the replacement. It must be kept in place to preserve the ability to read existing
model data.


### Adding Validation Constraints with protovalidate

[protovalidate](https://buf.build/docs/protovalidate/) can be used to constrain fields beyond what Protobuf's
type system expresses. Import it and annotate:

```proto
import "buf/validate/validate.proto";

// The opacity (alpha) applied to an entity, from 0 (transparent) to 1 (opaque).
message Opacity {
  option (motif.extension.v1.message).component = 34;

  // Opacity in the range [0, 1].
  float value = 1 [(buf.validate.field).float = {
    gte: 0
    lte: 1
  }];
}
```

## Tooling

Tooling is installed through [`mise`](https://mise.jdx.dev/). After
[installing mise](https://mise.jdx.dev/getting-started.html):

```sh
mise trust      # once, to allow this repo's config
mise install    # installs the pinned tool versions
```

The mise config sets a `min_version`, which is raised from time to
time; if mise refuses to run because of it, upgrade mise itself (`mise
self-update`, or via your package manager) and re-run `mise install`.

### Running Format and Lint with mise

Format first, then lint. Both are the same checks CI runs:

```sh
mise run format
mise run lint
```

Because `buf breaking` compares against your local `origin/main` ref, fetch
before you trust the result.

Other tasks: `mise run next-id` and `mise run check-id-gaps` (both described
above), and `mise tasks` to list everything.

### What CI Runs

Two workflows gate a pull request:

- **Buf CI** ([`.github/workflows/buf.yaml`](.github/workflows/buf.yaml)) — build,
  lint, format, and breaking-change detection against the PR base branch, via
  `bufbuild/buf-action`. Results appear as inline annotations plus a summary
  comment. On merge to `main`, the same workflow publishes the module to the Buf
  Schema Registry.
- **Component IDs**
  ([`.github/workflows/component-ids.yaml`](.github/workflows/component-ids.yaml))
  — the ID-gap check.

`mise run lint` locally covers everything the PR checks do. Running it before you
push is the difference between one review round and three.