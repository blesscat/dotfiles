Analyze the current branch commits and create a pull target: $ARGUMENTS (target branch name)

Add ticket number as hyperlink at the beginning (hyperlink format: [ticket_number](https://taroko.atlassian.net/issues/{ticket_number}))

**IMPORTANT**: Must confirm branch differences to ensure PR content accuracy

1. Use @.github/pull_request_template.md as template
2. **Verify current branch and target branch first** - check `git branch` and confirm target
3. Run `git log --oneline [target_branch]..HEAD` to see ONLY commits from current branch
4. Run `git diff [target_branch]..HEAD --stat` to see file changes specific to this branch
5. **Exclude unrelated commits** - only include changes made in the current branch vs target
6. Based on the branch-specific commits, create a descriptive PR title and description
7. **Focus only on relevant changes** - avoid including unrelated commits or changes from other branches
8. Follow our PR template structure exactly
9. Use `gh pr create` to submit the PR
10. Provide the PR URL when complete
