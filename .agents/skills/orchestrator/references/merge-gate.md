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
   - A head that only updates onto a newer main, with the PR's own diff
     unchanged, needs no new Code Review and no new Security Review. Its skip
     comment reads "Code and Security Review not required for head X: PR diff
     unchanged from Y".
   - Accept it only when Y has passing receipts for both reviews, and the
     `pr-review-follow-up` unchanged-diff check, run by you for X against Y,
     prints `PR diff unchanged`.
   - Any change to the PR's own diff needs both reviews on the new head.
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
  gates, ask again. In a batch merge, main moving only by merges of the same
  batch does not void it.
- Before merging, re-run items 1 and 4–6 on the final head. In a batch merge,
  item 1 checks the main SHA the slot named, not current main.

## If main moves after Ready

This covers main moving while CI runs, or after CI passes but before the merge.
A batch merge (below) is the one exception.

1. Take the PR back to draft (`gh pr ready <n> --undo`).
2. Update it onto the new main.
3. Get the reviews the new head needs, under the project's review rule.
4. Get a fresh slot naming the new main SHA.
5. Mark it Ready once again.

Never merge a head whose CI ran on an older main, except in a batch merge.

## Batch merge

PRs may merge back-to-back, without updating onto the new main between them,
when all of these hold:

- **No shared files:** their changed files don't overlap at all. Compare
  `gh pr diff <n> --name-only` for every pair.
- **No shared surfaces:** none of them touches database migrations, shared
  contracts or shared code packages, CI workflows or pins, lockfiles or package
  manifests, and no two touch the same OpenSpec capability or change folder.
  The project skill names its paths; count every shared contract and shared
  code package, not only the main one.
- **Each PR is ready on its own head:** green CI on its current head, and its
  required reviews on that head.
- **Nothing else in between:** only PRs of the batch merge between them.

If any condition fails, use the normal path: update onto the new main, get the
reviews the new head needs, and run fresh CI.

- When granting the slots, name the batch's other PRs in each grant. Main
  moving only by their merges leaves the slot valid.
- Merge each PR with `--match-head-commit` on its own head.
- After the last PR of the batch merges, watch the combined main delivery to
  its actual conclusion.
- If it is red, revert the last-merged PR and fix it. Nothing else merges
  while main is red.

## Merging

- The PR goes Ready once, and CI runs once on the final head.
- When the required checks pass on that head:
  `gh pr merge <n> --squash --match-head-commit <sha>`.
- Watch main's delivery in the background (`gh run watch <id> --exit-status`)
  and read its actual conclusion before reporting it. While main is red,
  nothing else merges.
