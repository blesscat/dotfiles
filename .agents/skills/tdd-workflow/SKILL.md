---
name: tdd-workflow
description: Use test-first development when explicitly requested or when a behavioral change benefits from a focused regression test.
---

# TDD Workflow

For new or corrected behavior that warrants automated regression coverage:

1. Write a focused test of the observable contract.
2. Run it and verify it fails for the intended missing behavior.
3. Implement the complete requested behavior and confirm the test passes.
4. Refactor if useful, then run affected regression tests and required project checks.

For behavior-preserving refactors, establish a passing baseline with existing
tests and rerun them after the change. Add coverage only for a meaningful gap;
do not invent new failing tests for unchanged behavior.

Documentation, formatting, simple visual edits, and other low-impact changes do
not automatically require new tests. Honor an explicit user request for TDD.

Assert behavior rather than implementation shape. Do not reduce requirements to
make a test pass. Investigate difficult tests for coupling or missing seams
without assuming that every hard-to-test requirement has a bad design.

Report checks actually run and any verification gaps. Reuse valid results until
new changes or failures justify rerunning them.
