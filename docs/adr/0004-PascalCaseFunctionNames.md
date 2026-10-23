# 0004. PascalCase function names

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

The team agreed on one naming style for the whole codebase: PascalCase for files, types, functions and assets, camelCase for variables. Apple's Swift API Design Guidelines use lowerCamelCase for functions, and so do SwiftLint and the agent skills by default.

## Decision

We will name functions and methods in PascalCase (`func LoadProfile()`), and keep camelCase for variables, properties, parameters and enum cases. Names that Apple defines must stay as they are: protocol requirements and overrides (`body`, `hash(into:)`, `setUpWithError()`, delegate methods) and XCTest methods, which must start with lowercase `test`.

## Alternatives considered

- **Apple's lowerCamelCase for functions:** matches Swift convention and the tools, but the team chose PascalCase as its house style.
- **The Swift API Design Guidelines agent skill:** rejected because it would push agents to rename functions to camelCase.

## Consequences

- Code reads differently from Apple's samples and most open-source Swift.
- `.swiftlint.yml` turns off `identifier_name`'s lowercase check and adds a custom rule that keeps variables camelCase.
- SwiftLint cannot tell team functions from Apple-defined ones, so reviewers catch camelCase functions.
- See AGENTS.md "Naming".
