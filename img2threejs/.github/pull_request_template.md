<!--
Thanks for contributing to img2threejs. Keep the pull request focused and remove instructional comments that do not apply before submitting.
-->

## Summary

<!-- What behavior or documentation changes? Why is it needed? Link related issues with "Refs #123" where applicable. Do not use closing keywords: maintainers close issues manually after final verification. -->

## Changes

<!-- List the key changes. -->

-

## Description matches the diff

- [ ] The title and summary describe exactly what the diff changes (no unrelated files, no commits inherited from another PR). `docs:` PRs touch only docs; CI enforces this.

## Verified

<!-- REQUIRED. Commands you actually ran and their key output (paste the relevant lines). "N/A" only for pure typo fixes. -->

## Unverified claims

<!-- REQUIRED. Anything stated in docs or code comments that you did NOT execute or confirm (install steps, versions, performance, behavior on other hosts). Write "None" or list each item; do not state unverified items as fact in the docs. -->

## Validation

<!-- Record the checks you ran and their results. Include render/comparison-sheet evidence for changes that affect reconstruction quality. -->

- [ ] `python3 forge/tests/test_pipeline.py`
- [ ] Relevant targeted validation or test:
- [ ] Render or comparison-sheet review, if applicable:

## Contributor checklist

- [ ] This PR keeps the code-only procedural reconstruction contract; it does not silently download meshes or art packs.
- [ ] Existing object specs remain valid, or this PR documents the intentional compatibility change.
- [ ] I added or updated tests for new gates, schema fields, or templates where applicable.
- [ ] I updated documentation and roadmap status where applicable.
