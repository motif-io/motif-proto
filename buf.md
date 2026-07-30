# Motif Platform

Protobuf schemas for the Motif platform.

## Overview

Schemas are grouped at a high level into the following packages:
- **`motif.api.v1`** - gRPC service API for the Motif platform
- **`motif.data.<subpackage>.v1`** — Component types defined by Motif, grouped by subpackage
- **`motif.events.v1`** - Message types for notification events sent by the Motif platform
- **`motif.extension.v1`** — Custom protobuf options and types used to extend the Motif platform with new Component types

## Usage

Add this module to the `deps` list in your `buf.yaml`:

```yaml
deps:
  - buf.build/motif/platform
```

Pin the dependency in your `buf.lock`:

```sh
buf dep update
```

Then import the schemas by their module-root-relative path, for example:

```proto
import "motif/extension/v1/options.proto";
import "motif/extension/v1/reference.proto";
```

## License

These schemas are licensed under the MIT License. The license covers the schemas
and the code you generate from them; use of the Motif platform itself is governed
by your agreement with Motif.

Packages under `thirdparty.<partner>.*` hold partner-owned component types,
normally contributed by the partner themselves. A contributor retains copyright
in what they contribute and licenses it under the MIT terms above.

Partner names and marks are the property of their respective owners.
