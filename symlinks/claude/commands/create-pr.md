Analyze the current branch commits and create a pull request: $ARGUMENTS (target branch name)

Add ticket number as hyperlink at the beginning (hyperlink format: [ticket_number](https://taroko.atlassian.net/issues/{ticket_number}))

1. Use @.github/pull_request_template.md as template
2. Run `git log --oneline origin/main..HEAD` to see commits
3. Run `git diff origin/main..HEAD --stat` to see file changes
4. Based on the commits, create a descriptive PR title and description
5. Follow our PR template structure exactly
6. Use `gh pr create` to submit the PR
7. Provide the PR URL when complete
