# Release Checklist

Quick checklist for creating releases of Optimize-WsusServer.

## Pre-Release Tasks (1-2 days before)

- [ ] Review closed issues and merged PRs since last release
- [ ] Update `CHANGELOG.md` with user-facing changes
- [ ] Review code for obvious bugs or issues
- [ ] Run tests locally: `Invoke-Pester Tests/`

## Version Preparation (Day of release)

- [ ] Determine new version number following [Semantic Versioning](https://semver.org/)
  - PATCH for bug fixes: `2.1.0` → `2.1.1`
  - MINOR for new features: `2.1.0` → `2.2.0`
  - MAJOR for breaking changes: `2.1.0` → `3.0.0`

- [ ] Update version in `Optimize-WsusServer.psd1`:
  ```powershell
  ModuleVersion = '2.1.1'
  ```

- [ ] If pre-release, add `Prerelease` field:
  ```powershell
  Prerelease = 'beta'  # Results in v2.1.1-beta
  ```

## Code Quality Checks

- [ ] Verify no uncommitted changes: `git status`
- [ ] Run PSScriptAnalyzer:
  ```powershell
  Invoke-ScriptAnalyzer -Path ./Public, ./Private -Settings PSScriptAnalyzerSettings.psd1
  ```
  All results should be clean (no errors)

- [ ] Build monolithic script:
  ```powershell
  .\Build\Build-MonolithicScript.ps1
  ```
  Should show: `Validation: PASSED ✓`

- [ ] Run full test suite:
  ```powershell
  Invoke-Pester Tests/ -PassThru
  ```
  All tests should pass

## Git Commit

- [ ] Commit version changes:
  ```powershell
  git add Optimize-WsusServer.psd1 CHANGELOG.md
  git commit -m "chore(release): prepare v2.1.1"
  ```

- [ ] Verify commit looks correct: `git log -1 --stat`

## Create Release Tag

- [ ] Create annotated tag (required for release workflow):
  ```powershell
  git tag -a "v2.1.1" -m "Release v2.1.1"
  ```

- [ ] Verify tag was created: `git tag -l -n5 | head -5`

## Push and Trigger Workflow

- [ ] Push commits:
  ```powershell
  git push origin main
  ```

- [ ] Push tag (this triggers GitHub Actions workflow):
  ```powershell
  git push origin "v2.1.1"
  ```

## Monitor Release

- [ ] Go to GitHub Actions: https://github.com/lusoris/Optimize-WsusServer/actions
- [ ] Watch for 3 jobs to complete:
  - [ ] **build** - Should show "✓ Workflow successful"
  - [ ] **publish-gallery** - Should show "✓ Successfully published" (if NUGET_KEY is set)
  - [ ] **post-release** - Should complete without errors

- [ ] **build job** details:
  - [ ] Manifest validated ✓
  - [ ] PSScriptAnalyzer passed ✓
  - [ ] Monolithic script built ✓
  - [ ] Script validation passed ✓
  - [ ] Release notes generated ✓

- [ ] **publish-gallery job** details (if NUGET_KEY is set):
  - [ ] Manifest updated to version ✓
  - [ ] Module validated for gallery ✓
  - [ ] Published successfully ✓

## Post-Release Verification

- [ ] GitHub Release created: https://github.com/lusoris/Optimize-WsusServer/releases
  - [ ] Release name: `Optimize-WsusServer v2.1.1`
  - [ ] Contains 4 files:
    - `Optimize-WsusServer.ps1` (monolithic script)
    - `Optimize-WsusServer.psd1` (manifest)
    - `Optimize-WsusServer-Module.zip` (full module)
    - `LICENSE`

- [ ] PowerShell Gallery (if NUGET_KEY configured): https://www.powershellgallery.com/packages/Optimize-WsusServer/
  - [ ] Module appears
  - [ ] Version shows `2.1.1`
  - [ ] Can install: `Install-Module Optimize-WsusServer -RequiredVersion 2.1.1`

## Announce Release

- [ ] Add comment to any related issues that this resolves
- [ ] Update project website/documentation if applicable
- [ ] Notify users (email, forums, etc.) if major release

## Rollback (If needed)

If something goes wrong after publishing:

### Rollback from PowerShell Gallery only

1. Do NOT delete the tag
2. Create a new version with the revert:
   ```powershell
   # Update psd1 to v2.1.2
   git add Optimize-WsusServer.psd1
   git commit -m "chore(release): revert changes in v2.1.2"
   git tag -a "v2.1.2" -m "Hotfix: revert v2.1.1"
   git push origin main
   git push origin "v2.1.2"
   ```

### Rollback everything

1. Delete the tag:
   ```powershell
   git tag -d "v2.1.1"
   git push origin --delete "v2.1.1"
   ```

2. Delete the GitHub release manually
3. Delete manifest bump commit (if not yet pushed):
   ```powershell
   git reset --hard HEAD~1
   ```

## Common Issues

**Problem:** Workflow fails with "Manifest version doesn't match tag"
- **Fix:** Ensure `ModuleVersion = '2.1.1'` matches the tag `v2.1.1`
- Delete tag, fix version, recreate tag

**Problem:** Module not published to PowerShell Gallery
- **Fix:** Check if `NUGET_KEY` is configured in GitHub settings
- If missing, set up the secret and recreate the release

**Problem:** Build fails with PSScriptAnalyzer errors
- **Fix:** Run locally first: `Invoke-ScriptAnalyzer -Path ./Public -Settings PSScriptAnalyzerSettings.psd1`
- Fix errors locally, commit, delete tag, recreate

## Time Estimate

- Pre-release tasks: 20-30 minutes
- Version prep + checks: 10-15 minutes
- Workflow execution: 3-5 minutes
- Verification: 5-10 minutes
- **Total: 40-60 minutes**

## Quick Reference Commands

```powershell
# Everything in one go (after updating version in psd1)
$version = "2.1.1"
git add Optimize-WsusServer.psd1
git commit -m "chore(release): prepare v$version"
git tag -a "v$version" -m "Release v$version"
git push origin main
git push origin "v$version"

# Then monitor at:
# https://github.com/lusoris/Optimize-WsusServer/actions
```

## See Also

- [Release Process Documentation](./RELEASE-PROCESS.md)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
