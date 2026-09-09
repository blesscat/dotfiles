---
name: find-skills
description: Find installable skills when the user asks to discover or install one, or an established capability gap requires an extension.
---

# Find Skills

First check whether an available skill or tool already handles the request.
Ordinary requests such as "how do I do X" do not by themselves require searching
for extensions. Search when the user asks for skills or a concrete capability
gap makes an extension relevant.

Use a focused query through the Skills CLI, such as
`npx skills find <query>`, or the skills.sh catalog. Consult current CLI help
before relying on installation flags.

Before recommending a candidate, inspect its actual SKILL.md and relevant
scripts, dependencies, tool requirements, maintenance, and source provenance.
Evaluate task fit, compatibility, excessive triggers, side effects, and overlap
with installed skills. Stars and install counts are secondary signals, not
quality thresholds or substitutes for inspecting the content.

Present the strongest relevant options with source links, tradeoffs, and the
installation scope. Install only when the user requests installation; preserve
the chosen project or user-level location and avoid duplicate copies.
A search request alone does not authorize installation or updating other skills.

If no suitable skill exists, explain the gap and continue any useful work
possible with existing capabilities. Suggest creating a skill only when a
reusable workflow would add concrete value.
