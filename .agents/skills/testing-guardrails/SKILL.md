---
name: testing-guardrails
description: Use when writing, reviewing, or modifying automated tests in codebases. Enforces behavior-focused tests and rejects brittle tests that inspect source text or implementation strings unless source text is the actual product under test.
---

# Testing Guardrails

When writing or changing tests, assert behavior, public contracts, user-visible effects, or observable outputs.

Do not write tests that read source files and assert implementation strings, import paths, hook names, helper names, or exact code structure. These tests are brittle and make refactors noisy without proving behavior.

Do not duplicate production configuration values in test expectations. If a test imports a config object or verifies that code applies a configurable value, avoid `toBe(6000)`-style assertions against copied literals. Prefer asserting observable behavior, importing the same exported domain constant used by production code, or checking relationships and preservation of unrelated fields. Literal numbers are fine for local test inputs when the number defines the scenario, not when it mirrors mutable config file contents.

Allowed exception: source text inspection is valid only when the task itself is static analysis, linting, codemods, code generation, compiler/transpiler output verification, or another tool where source text is the product under test.

If a regression appears tied to implementation shape, test the externally observable contract instead. Examples:
- Test resolved asset URLs are concrete strings, not that code uses `new URL`.
- Test missing refs are skipped, not that a specific hook contains a specific guard line.
- Test an event is emitted, not that a source file contains a call expression.
- Test a feature applies `FEATURE_TIMING_CONFIG`, not that copied values are exactly `3500` and `1000`.

Before adding any source-text assertion, stop and ask whether the source text itself is the behavior being specified. If not, choose a behavioral test.
