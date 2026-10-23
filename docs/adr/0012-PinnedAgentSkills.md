# 0012. Pinned agent skills, installed per developer

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

AI agents' Swift knowledge goes out of date quickly. Community agent skills fix this, but they are third-party text that agents follow, so a changed skill could change agent behavior or carry harmful instructions.

## Decision

We will use six skills:

- `swiftui-pro`, `swiftdata-pro`, `swift-concurrency-pro` and `swift-testing-pro` by Paul Hudson,
- `ios-accessibility`,
- `swift-security-expert`.

`Scripts/InstallAgentSkills.sh` installs them into the git-ignored `.agents/skills/` folder and links them into `.claude/skills/`. Each skill is pinned to a commit that was read before use.

## Alternatives considered

- **Several skills per topic:** overlapping skills give conflicting advice.
- **The Swift API Design Guidelines skill:** conflicts with PascalCase functions ([0004](0004-PascalCaseFunctionNames.md)).
- **A general architecture skill:** may push patterns that conflict with MVVM layer-first ([0003](0003-MvvmLayerFirst.md)).
- **Skills for features we do not have yet (widgets, App Intents, background tasks):** add noise; add them when needed.
- **Committing the skills into the repository:** keeps third-party content in our history and mixes per-developer setup into the codebase.
- **Installing the latest version each time:** convenient, but unreviewed changes would reach every agent.

## Consequences

- Each developer runs the install script once after cloning.
- Updating a skill means reading the new version and changing its commit in the script.
- AGENTS.md wins over any skill when they conflict.
- See AGENTS.md "Agent skills".
