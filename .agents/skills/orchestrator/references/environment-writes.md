# Writes to staging or other environments

## Staging and other non-production environments

1. **Read-only plan.** The worker inventories the live state with read-only
   calls and proposes the exact targets and writes.
2. **Script file.** The worker writes the script to a file in the handoff
   folder. Nothing runs yet.
3. **Hub checks, then GO.**
   - Diff the script against the last approved version
     (`diff -u <approved> <new>`). Every changed line needs a reason.
   - Check the live state yourself, read-only, querying named fields only.
   - Give a GO that names the exact targets and the allowed writes. Anything
     not named is not allowed.
4. **Run.** Any failure means stop: no retry, no workaround. Report.
5. **Receipt.** The worker writes a receipt: what ran, each target's result,
   the post-checks and a sanitized log. Spot-check some items independently
   before accepting it.

## Production

1. Create the change set or plan. Don't execute it.
2. Show the owner what it changes and get the owner's explicit OK in this
   session.
3. Right before executing, run a drift or fresh check. If anything differs from
   what the owner approved, stop and ask again.
4. Execute only the approved set. Receipt and spot-check as above.
