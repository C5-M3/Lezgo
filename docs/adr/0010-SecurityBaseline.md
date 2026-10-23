# 0010. Security baseline

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

The repository is shared between people and AI agents, and agents can leak secrets or add unsafe code without noticing. XCSSET malware spreads through shared Xcode projects. Supply-chain attacks target CI actions and downloaded tools.

## Decision

We will:

- keep secrets out of git (`.env`, `Secrets.swift`, `Secrets.xcconfig` are ignored; Gitleaks scans history),
- store credentials in the Keychain only,
- use HTTPS only,
- validate all outside input,
- never log personal data or tokens,
- use CryptoKit for cryptography.

In CI and tooling, we pin third-party GitHub Actions to full commit SHAs, verify downloaded tools by checksum or image digest, give workflows read-only permissions, and pass user-controlled text through environment variables instead of `${{ }}`.

## Alternatives considered

- **Version tags for actions (`@v7`):** easier to update, but a tag can be moved to malicious code.
- **The paid Gitleaks GitHub Action:** requires a license for organizations; running the free CLI with a verified checksum gives the same scan.

## Consequences

- Updating an action or tool means looking up and reviewing the new SHA or checksum.
- `Scripts/ScanForXcsset.sh` warns on every build script phase so a reviewer reads it.
- See AGENTS.md "Security" and "Continuous integration".
