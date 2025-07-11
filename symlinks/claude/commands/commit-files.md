Create a commit based on staged files in the current branch: $ARGUMENTS (optional JIRA ticket number in brackets [])

1. Run `git status` to check the current working directory state.
2. Run `git diff --cached` to review staged (indexed) changes.
3. Run `git log --oneline -5` to observe recent commit message styles.
4. Analyze the changes and prepare a descriptive commit message using the Conventional Commits format.
5. Include the JIRA ticket ID at the beginning of the message (e.g., feat: \[HUE1-1234\] ...).
6. Run `git commit -m "message"` with your crafted message.
7. Run `git log -1` or `git show` to confirm the commit was created as expected.
