# Pending workflow

`ci.yml` lives here rather than in `.github/workflows/` because GitHub rejects
a push that creates or updates a workflow when the token lacks the `workflow`
scope, and that rejection blocks the whole push, not just that file.

To activate it:

```bash
gh auth refresh -s workflow
git mv .github/workflows-pending/ci.yml .github/workflows/ci.yml
git commit -m "Enable CI" && git push
```
