#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(git rev-parse --show-toplevel)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

cd "$repo_dir"
buf build --as-file-descriptor-set -o "$test_dir/baseline.binpb"
mkdir "$test_dir/candidate"
cp -R proto "$test_dir/candidate/proto"
cp buf.yaml buf.lock "$test_dir/candidate/"
schema=proto/motif/data/annotation/v1/annotation.proto
candidate="$test_dir/candidate/$schema"

assert_fixture_changed() {
  if cmp -s "$schema" "$candidate"; then
    echo "Evolution fixture did not change the schema; check its insertion pattern." >&2
    exit 1
  fi
}

# Existing owners may acquire reference-free selector metadata. This checks
# structural evolution only; new authored semantics still need a reader-version bump.
awk '/^message DimensionSource \{/ {
  print; print "  uint32 future_selector_option = 6;"; next
} { print }' "$schema" > "$candidate"
assert_fixture_changed
buf breaking "$test_dir/candidate" --against "$test_dir/baseline.binpb"
echo "Reference-free source metadata remains structurally additive."

expect_reference_break() {
  local output status=0
  output=$(buf breaking "$test_dir/candidate" --against "$test_dir/baseline.binpb" --error-format=json 2>&1) || status=$?
  if [[ "$status" -ne 100 ]]; then
    printf '%s\n' "$output" >&2
    echo "Expected a schema evolution violation, got status $status." >&2
    exit 1
  fi
  case "$output" in
    *MOTIF_COMPONENT_REFERENCE_ADDED*) ;;
    *) printf '%s\n' "$output" >&2; echo "Expected the reference-addition rule." >&2; exit 1 ;;
  esac
}

awk '/^message DimensionSource \{/ {
  print; print "  motif.extension.v1.EntityReference additional_owner = 6;"; next
} { print }' "$schema" > "$candidate"
assert_fixture_changed
expect_reference_break
echo "Adding another owner to an existing source is rejected."

awk '/^  message CircularGeometry \{/ {
  print; print "    motif.extension.v1.EntityReference source_owner = 2;"; next
} { print }' "$schema" > "$candidate"
assert_fixture_changed
expect_reference_break
echo "Adding a reference inside circular Dimension metadata is rejected."
