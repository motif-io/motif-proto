# Contributing to motif-proto

The Motif platform uses an extensible data model, with Protobuf being used
to define "components" as structured data attached to an entity. Contributors
to this repo can define new component types, and use them to write data into
a model in Motif. Guides and reference for building on Motif are at
[developers.motif.io](https://developers.motif.io).

## Package Layout

Schemas live under `proto/`, each file in the directory that mirrors its
package name (package `motif.data.core.v1` is at `proto/motif/data/core/v1/`).
Imports use the path relative to `proto/`, e.g.
`import "motif/extension/v1/options.proto";`. [`buf.md`](buf.md) lists the
top-level packages. Every package ends in a version that complies with buf's
[`PACKAGE_VERSION_SUFFIX`](https://buf.build/docs/lint/rules/#package_version_suffix)
lint rule, such as `v1`; `buf lint` checks it.

All schemas form a single
[buf module](https://buf.build/docs/configuration/v2/buf-yaml) rooted at
`proto/`, published as one Buf Schema Registry repository. Add a package by
creating its package-mirrored directory under `proto/`; no `buf.yaml` change
is needed.

Component types live only in `motif.data.<subpackage>.v1` (for Motif) or
`thirdparty.<org>.data.<domain>.v1` (for partners). Motif-owned types go in
the `motif.data` subpackage that fits the domain (e.g. `core`, `model`,
`view`, `style`, `fde`), or in a new one if none fits.

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

This prints one more than the highest component ID assigned anywhere in
the schemas, including nested messages. IDs are never reused, even after a
type is removed, so always take the value it prints rather than filling a gap
or picking a number far from the sequence. `mise run check-id-gaps` fails when
too many consecutive IDs are left unused between two assigned IDs, as a guard
against typos like `600` for `60`. The threshold is set in
[`.config/mise.toml`](.config/mise.toml).

`next-id` reads your local working tree, so prior to merging, you may need to renumber
your component IDs based on the current state of `main` due to conflicting
component IDs merged by other contributors. Your pull request will not be
accepted until such conflicts are resolved.

The top 10,000 IDs, 2147473648 through 2147483647 (the int32 maximum), are
reserved for component types a model defines for its own use in a
`motif.data.schema.v1.ComponentSchema`. Never assign them to a component type
in this repository. `mise run check-reserved-ids` fails if one does.

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

Set the `(motif.extension.v1.field).data_reference_expected_type` option on
every `DataReference` field to declare the type of the data it points at, as
`design_load` does above. The expected type is the only record of what kind of
data stored references point at, which is why it cannot change once merged
(see below). A field without an expected type may gain one later.

Use `RepresentationReference` for representation blob IDs. See the
[`motif.extension.v1` package docs](https://buf.build/motif/platform/docs/main%3Amotif.extension.v1)
for more information about each reference type, and
[`options.proto`](proto/motif/extension/v1/options.proto) for the full set of
Motif message and field options.

**References are fixed once merged.** The `MOTIF` breaking rules reject adding a
field that can carry a reference to an existing component type (or to a
message it contains), retyping a field so that it can, and changing or removing
a `DataReference` field's expected type (the
`MOTIF_DATA_REFERENCE_EXPECTED_TYPE_CHANGED` rule). Decide a component's
references before it merges; to add one later, or to reference a different
type, define a new component type.

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
import "motif/extension/v1/options.proto";

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

## Developing a Component Type in a Model

A new component type can be developed and used in a model before it is added to
this repository. The model stores the type's schema in a
`motif.data.schema.v1.ComponentSchema` component, and the type is usable only in
that model. The rules for that schema are in
[`schema.proto`](proto/motif/data/schema/v1/schema.proto).

1. Write the type in your local checkout of this repository. It stays local:
   the type is only being developed here, so don't commit its directory or
   open a pull request for it until it's ready to move into the platform.
   `.gitignore` ignores `test` version directories under `proto/`, and the
   build artifacts below go in `.model-schema/`, which is ignored too. While
   the type exists, `mise run check-reserved-ids` (part of `mise run lint`)
   fails and names it, as a reminder that it must not be committed.

   - Choose an unstable version of the package the type will join, following
     buf's [version suffix rules](https://buf.build/docs/lint/rules/#package_version_suffix):
     for example `motif.graphics.v1test1` in `proto/motif/graphics/v1test1/`
     for a type headed for `motif.graphics.v1`, or
     `thirdparty.acme.data.structure.v1test1` for one headed for
     `thirdparty.acme.data.structure.v1`. An unstable version prevents the type
     from conflicting with the stable package's files and types, and the type
     moves into that package by dropping the suffix. A `test` version can be
     numbered, such as `v1test1`, or named for what you're building, such as
     `v1testgeolocation`; pick one this repository doesn't already use.
   - Give the type a component ID from the range reserved for model-defined
     types, starting at 2147473648 (see
     [Choosing a Component ID](#choosing-a-component-id)).

2. Build the schema from that directory alone, without its imports, which are
   read from the platform:

   ```sh
   mkdir -p .model-schema
   buf build --path proto/motif/graphics/v1test1 --exclude-imports -o .model-schema/schema.binpb
   ```

3. Encode it as a `ComponentSchema` value:

   ```sh
   echo "{\"fileDescriptorSet\":\"$(base64 < .model-schema/schema.binpb | tr -d '\n')\"}" \
     | buf convert . --type motif.data.schema.v1.ComponentSchema \
         --from -#format=json --to -#format=binpb \
     | base64 | tr -d '\n' > .model-schema/value.b64
   ```

4. Write the value to the model with `motif.api.v1.Persistence/ApplyChangeset`,
   as component `254` (`ComponentSchema`) on the model entity
   `00000000-0000-4000-8000-000000000000`. Set `maxKnownVersion` to the model's
   current version, which `ListModels` reports, so a schema written since is
   not overwritten. IDs are bytes, which JSON writes in base64, so the `b64`
   helper converts each UUID:

   ```sh
   b64() { echo "$1" | tr -d - | xxd -r -p | base64; }

   PROJECT_ID=<project id>
   MODEL_ID=<model id>
   MODEL_VERSION=<current model version>

   cat > .model-schema/changeset.json <<EOF
   {
     "projectId": "$(b64 "$PROJECT_ID")",
     "modelId": "$(b64 "$MODEL_ID")",
     "maxKnownVersion": $MODEL_VERSION,
     "changes": [
       {
         "entityId": "$(b64 00000000-0000-4000-8000-000000000000)",
         "components": [{ "typeTag": 254, "value": "$(cat .model-schema/value.b64)" }]
       }
     ]
   }
   EOF

   buf curl --schema . --protocol grpc \
     -H "Authorization: Bearer $MOTIF_PAT" -d @.model-schema/changeset.json \
     https://<persistence endpoint>/motif.api.v1.Persistence/ApplyChangeset
   ```

   A schema that breaks a rule is refused with `INVALID_ARGUMENT`, and nothing
   is written. To extend the schema later, build and write it again the same
   way: each value replaces the last, so it must hold all of the model's types.

   A change follows the same breaking-change rules as a platform change, and
   `buf breaking` checks it the same way. Before changing the files, build the
   version the model holds, with its imports, then compare the changed files to
   it:

   ```sh
   buf build --path proto/motif/graphics/v1test1 -o .model-schema/previous.binpb   # before changing
   buf build --path proto/motif/graphics/v1test1 -o .model-schema/current.binpb    # after
   buf breaking .model-schema/current.binpb --against .model-schema/previous.binpb
   ```

   The server enforces the part of these rules that protects stored data, so it
   also accepts some changes `buf breaking` reports, such as renames. For an
   incompatible change, move the types to the next version,
   `motif.graphics.v1test2`, with new component IDs, and keep `v1test1` in the
   set, passing `--path` once for each directory.

5. Generate code for the type in the repository that uses it, which has its own
   `buf.gen.yaml`. The type is not published to the Buf Schema Registry, so
   generate from this checkout, limited to the development directory:

   ```sh
   buf generate ../motif-proto --path ../motif-proto/proto/motif/graphics/v1test1
   ```

   Then write components of the new type to the model under its reserved ID.

Experiment in a throwaway model: once a model accepts a schema, its types can
gain fields but not lose them, and the model keeps them.

When the type is ready, move it into its final file and package (drop the
version's suffix, `v1test1` to `v1`, and remove the directory), assign it a
platform component ID with `mise run next-id`, and open a pull request. Code
written against the development type needs only the new package and ID. Data
written under the reserved ID stays with the development model.

## Commits and Pull Requests

This repository is public, so treat every commit and pull request as externally
visible:

- Do not manually add `Co-authored-by`, `Made-with`, or other tool/AI
  attribution trailers to commits or pull requests.
- Do not link to private or internal systems (such as private issue trackers)
  or paste internal-only URLs or ticket IDs in commit messages or pull request
  descriptions.
- Prefer a short subject plus optional technical rationale; no ticket footers.

### Your Commit Email

The author and committer email on every commit you push becomes public. We recommend your GitHub
[noreply address](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address#setting-your-email-address-for-a-single-repository)
(`<id>+<username>@users.noreply.github.com`); a public address you are
comfortable sharing is also fine. To set it for this repository only:

```sh
git config user.email "<id>+<username>@users.noreply.github.com"
```

Motif engineers must use their noreply address, with "Keep my email addresses
private" and "Block command line pushes that expose my email" turned on in
their GitHub email settings.

`main` rejects any new commit whose author or committer email is a Motif work
address or a machine-generated address, such as one ending in `.internal` or
`.local` that git creates when no email is configured, and any commit with a
`Co-authored-by` trailer naming one of those addresses. Other branches are not
checked, but a squash merge into `main` adds a `Co-authored-by` trailer for
each other author of the branch's commits, so a single commit with one of those
addresses blocks the merge. To fix a branch, set `user.email`, rewrite the email
on your branch's commits, and force-push:

```sh
git rebase --exec 'git commit --amend --no-edit --reset-author' origin/main
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

Format first, then lint before you push:

```sh
mise run format   # buf format -w + taplo fmt
mise run lint     # buf format check, buf lint, buf breaking, taplo check, component ID checks
```

`mise run lint` covers everything the pull request checks do:
[Buf CI](.github/workflows/buf.yaml) (build, lint, format, and breaking-change
detection, which also publishes the module to the Buf Schema Registry on merge
to `main`) and the [component ID](.github/workflows/component-ids.yaml) gap
and reserved-ID checks. Because `buf breaking` compares against your local `origin/main` ref,
fetch before you trust the result.

Other tasks: `mise run next-id`, `mise run check-id-gaps` and
`mise run check-reserved-ids` (all described above), and `mise tasks` to list everything.