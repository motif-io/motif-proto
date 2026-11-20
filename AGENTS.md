# Working in motif-proto

Follow [CONTRIBUTING.md](CONTRIBUTING.md) to add or change schemas;
[`buf.md`](buf.md) lists the top-level packages. In particular:

- Component IDs come from `mise run next-id`; never pick one by hand.
- Run `mise run format`, then `mise run lint`, after every change.
- Commits and pull requests are public. Do not manually add `Co-authored-by`,
  `Made-with`, or other tool/AI attribution trailers, and do not reference
  internal systems, URLs, or ticket IDs. See
  [Commits and Pull Requests](CONTRIBUTING.md#commits-and-pull-requests).
