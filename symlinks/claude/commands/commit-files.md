Create a commit based on staged files in the current branch: $ARGUMENTS (optional JIRA ticket number in brackets [])

1. Run `git status` to see the current state
2. Run `git diff --cached` to review staged changes
3. Run `git log --oneline -5` to see recent commit style
4. Analyze changes and create an appropriate commit message following conventional commits format
5. Run `git commit -m "message"` with a descriptive message
6. Confirm the commit was created successfully
