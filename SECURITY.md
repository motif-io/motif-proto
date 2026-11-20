# Security Policy

## Reporting a vulnerability

Please do not report security vulnerabilities through public pull requests
or comments.

Report them privately through GitHub instead: go to the **Security** tab of
this repository and choose **Report a vulnerability**. Only the maintainers
can see the report.

Please include:

- What you found, and where (file, workflow, or published module).
- Steps to reproduce, or a proof of concept.
- The impact you expect.

We will acknowledge your report and keep you updated until it is resolved.
Please give us a reasonable chance to fix the issue before disclosing it
publicly.

## Scope

This repository holds Protobuf schemas and the CI that publishes them to the
Buf Schema Registry as `buf.build/motif/platform`. In scope:

- Secrets or credentials committed to this repository.
- Weaknesses in the GitHub Actions workflows, such as ways for a pull request
  to reach publishing credentials.
- Ways to publish unreviewed changes to the Buf Schema Registry module.
- Schema definitions that would lead consumers to handle data unsafely.

## Supported versions

Only the latest version on `main`, and the matching commit on the Buf Schema
Registry, receives security fixes.
