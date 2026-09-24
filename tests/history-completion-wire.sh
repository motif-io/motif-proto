#!/bin/sh
set -eu

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

message=motif.events.v1.NotificationEnvelope
fixture_dir=$(dirname "$0")/fixtures

buf build .git#ref=refs/remotes/origin/main --path proto/motif/events/v1/events.proto -o "$scratch/base.binpb"
buf build --path proto/motif/events/v1/events.proto -o "$scratch/current.binpb"

# The pre-existing project action must keep its exact binary representation.
buf convert "$scratch/base.binpb" --type "$message" --from "$fixture_dir/project-renamed.json" --to "$scratch/old-base.binpb"
buf convert "$scratch/current.binpb" --type "$message" --from "$fixture_dir/project-renamed.json" --to "$scratch/old-current.binpb"
cmp "$scratch/old-base.binpb" "$scratch/old-current.binpb"

# A completion must survive the real envelope and preserve project routing.
buf convert "$scratch/current.binpb" --type "$message" --from "$fixture_dir/history-finished.json" --to "$scratch/new.binpb"
buf convert "$scratch/current.binpb" --type "$message" --from "$scratch/new.binpb" --to "$scratch/new.json"
jq -e '.content.project.projectId == "AAAAAAAAAAAAAAAAAAAAAA==" and
  .content.project.historyEnrichmentFinished.modelId == "AQEBAQEBAQEBAQEBAQEBAQ==" and
  .content.project.historyEnrichmentFinished.version == 42 and
  .content.project.historyEnrichmentFinished.policyRevision == "rev1" and
  .content.project.historyEnrichmentFinished.status == "STATUS_COMPLETE"' "$scratch/new.json" >/dev/null

# Unknown future enum numbers must survive a decode/encode round trip.
jq '.content.project.historyEnrichmentFinished.status = 17' "$fixture_dir/history-finished.json" > "$scratch/unknown.json"
buf convert "$scratch/current.binpb" --type "$message" --from "$scratch/unknown.json" --to "$scratch/unknown.binpb"
buf convert "$scratch/current.binpb" --type "$message" --from "$scratch/unknown.binpb" --to "$scratch/unknown-decoded.json"
jq -e '.content.project.historyEnrichmentFinished.status == 17' "$scratch/unknown-decoded.json" >/dev/null
buf convert "$scratch/current.binpb" --type "$message" --from "$scratch/unknown-decoded.json" --to "$scratch/unknown-reencoded.binpb"
cmp "$scratch/unknown.binpb" "$scratch/unknown-reencoded.binpb"

echo "History completion envelope wire checks passed."
