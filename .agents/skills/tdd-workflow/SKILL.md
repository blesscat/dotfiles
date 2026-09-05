---
name: tdd-workflow
description: TDD workflow for feature work and bug fixes.
---

# TDD Workflow

## Purpose
Ensure Codex follows a test-first process when implementing features or fixing bugs.

## Core rules
- Write a failing test first
- Confirm the test actually fails
- Write the minimal implementation
- Confirm the test passes
- Refactor last

## Applicable scenarios
- New features
- Refactoring
- Behavioral changes

## Workflow
1. Write a minimal test
2. Run it and confirm the failure is correct
3. Write the smallest amount of code needed to pass
4. Run the test again and confirm it passes
5. Run any necessary regression tests
6. Only clean up the code after everything is green

## Acceptance checklist
- [ ] Every new behavior has a test
- [ ] The test fails before it passes
- [ ] The scope was not bent just to make the test pass
- [ ] All tests pass
- [ ] Refactoring did not break behavior

## Common mistakes
- Writing production code before the test
- Testing implementation details instead of behavior
- Changing too much at once, making failures hard to attribute

## Reminder to Codex
If the task is too large, split it first.
If the test is hard to write, the design is usually too complex.
