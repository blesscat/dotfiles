# Merge gate

## Before granting a slot

The worker asks while the PR is still a draft, with the head SHA, the review
receipt comment IDs and the unresolved-thread count. Verify each item yourself
on that exact head, after `git fetch origin`:

1. **Current main is an ancestor:**
   `git merge-base --is-ancestor origin/main <head-sha>`. If not, the slot
   names current main; the worker updates onto it and gets the reviews the new
   head needs.
2. **File-path scan** of `gh pr diff <n> --name-only`: no screenshots,
   evidence files or archives.
3. **The project's sensitive-data scan**, names-only.
4. **Review receipts on the exact head:** every required review has a receipt
   for the full head SHA, or a skip comment the project's rules allow.
5. **Threads re-counted after the receipts: 0 unresolved.**

   ```sh
   gh api graphql -F owner=<owner> -F repo=<repo> -F n=<pr> -f query='
     query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){
       pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved}}}}}' \
     --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length'
   ```

6. **No late comments:** nothing posted after the latest receipt is unanswered.

## Granting

- The slot names the main SHA.
- Only a conflict-free update onto that SHA is covered. Any other push, or main
  moving past that SHA before Ready, voids the slot: back to draft, redo the
  gates, ask again.
- Before merging, re-run items 1 and 4–6 on the final head.

## Merging

- The PR goes Ready once, and CI runs once on the final head.
- When the required checks pass on that head:
  `gh pr merge <n> --squash --match-head-commit <sha>`.
- Watch main's delivery in the background (`gh run watch <id> --exit-status`)
  and read its actual conclusion before reporting it. While main is red,
  nothing else merges.
