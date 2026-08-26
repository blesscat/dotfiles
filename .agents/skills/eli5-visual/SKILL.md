---
name: eli5-visual
description: Create a beginner-friendly visual explanation of a topic for someone with no prior knowledge. Use when the user explicitly asks for ELI5, a dead-simple explanation, or a visual explainer with large visuals and minimal text.
---

# eli5-visual

Explain the user's requested topic as if they know nothing about it.

When this skill is invoked:

- Lead with the core idea in one short sentence.
- Use a self-contained HTML document as the primary output when a visual explainer is appropriate.
- Use large, clear visuals and very little text. Prefer inline HTML, CSS, and SVG so the result works without external assets.
- Make each visual communicate one idea. Use labels, arrows, grouping, and simple visual metaphors where they improve understanding.
- Add only the details needed to understand the topic; define unavoidable technical terms immediately.
- Keep the explanation accurate. Simplify wording and structure, but do not invent facts or hide important caveats.
- End with why the concept matters or how the pieces fit together.
- Use a respectful, encouraging tone. Simple does not mean childish or condescending.
- If the user asks for a text-only explanation, answer directly in text instead of creating an HTML file.
- Do not rely on Claude-specific plugin commands, Artifact APIs, or `$ARGUMENTS`; use the user's current request as the topic.
