---
name: code-readability-guardrails
description: Use when writing or reviewing TypeScript, React, or application code where conditional object construction, nested ternaries, or dense expressions could make behavior harder to read.
---

# Code Readability Guardrails

Prefer explicit control flow when a conditional expression builds objects, arrays, JSX trees, or other multi-line values.

## Rules

- Do not use nested or multi-line ternaries to construct object literals.
- If a conditional branch returns an object, prefer a named helper with early returns.
- Keep ternaries for short scalar values only.
- Prefer intermediate variables with domain names over inline dense expressions.

## Pattern

Avoid:

```ts
const value = condition
  ? { x: source.left, y: source.top, width: source.width, height: source.height }
  : null
```

Prefer:

```ts
function getValue(source: Source | null) {
  if (!source) return null
  return {
    x: source.left,
    y: source.top,
    width: source.width,
    height: source.height,
  }
}
```
