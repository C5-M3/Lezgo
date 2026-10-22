#!/usr/bin/env bash
# Installs the agent skills listed in AGENTS.md into .agents/skills (Codex, Cursor, Gemini)
# and links them into .claude/skills (Claude Code). Both folders are git-ignored.
#
# Each skill is pinned to a commit that was read and reviewed. To update one,
# read the new version first, then change its commit below.

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
agentsSkillsDir="$repoRoot/.agents/skills"
claudeSkillsDir="$repoRoot/.claude/skills"
workDir="$(mktemp -d)"
trap 'rm -rf "$workDir"' EXIT

# Format: <skill name> <GitHub repository> <commit> <folder inside the repository>
skills=(
  "swiftui-pro twostraws/SwiftUI-Agent-Skill ce32af1693b9e78a7d22ff48001c97a304d32063 swiftui-pro"
  "swiftdata-pro twostraws/SwiftData-Agent-Skill 8051f177a0076e7fd45bdf4ee687b070ba58fdc6 swiftdata-pro"
  "swift-concurrency-pro twostraws/Swift-Concurrency-Agent-Skill bee3f69ba17142da148d3c5406f148ed62592b69 swift-concurrency-pro"
  "swift-testing-pro twostraws/Swift-Testing-Agent-Skill 2d6bba14a3c8bf3694f218b92fffe617c41ae43e swift-testing-pro"
  "ios-accessibility dadederk/iOS-Accessibility-Agent-Skill dcc3a36ce1d0099341d545c1af4eb5a8c989bf66 ios-accessibility"
  "swift-security-expert ivan-magda/swift-security-skill bda2e0ccee6a64d45ec2b93790d0876c90e4eb89 swift-security-expert"
)

mkdir -p "$agentsSkillsDir" "$claudeSkillsDir"

for entry in "${skills[@]}"; do
  read -r name repository commit folder <<< "$entry"
  checkoutDir="$workDir/$name"

  echo "Installing $name from $repository@${commit:0:7}"
  git init --quiet "$checkoutDir"
  git -C "$checkoutDir" fetch --quiet --depth 1 "https://github.com/$repository.git" "$commit"
  git -C "$checkoutDir" checkout --quiet FETCH_HEAD

  rm -rf "${agentsSkillsDir:?}/$name"
  mkdir -p "$agentsSkillsDir/$name"
  # Copy the skill itself; skip plugin metadata, icons and nested plugin copies.
  rsync -a --exclude "/.claude-plugin" --exclude "/agents" --exclude "/assets" --exclude "/skills" \
    "$checkoutDir/$folder/" "$agentsSkillsDir/$name/"

  rm -rf "${claudeSkillsDir:?}/$name"
  ln -s "../../.agents/skills/$name" "$claudeSkillsDir/$name"
done

echo "Done. Installed ${#skills[@]} skills into .agents/skills and linked them into .claude/skills."
