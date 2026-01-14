# Release Process for Optimize-WsusServer

This document describes how to create releases for Optimize-WsusServer and publish them to PowerShell Gallery.

## Quick Start

To create a new release:

```powershell
# 1. Update version in manifest
$newVersion = "2.1.1"
# Edit Optimize-WsusServer.psd1 and update ModuleVersion = '$newVersion'

# 2. Commit changes
git add Optimize-WsusServer.psd1
git commit -m "chore(release): prepare v$newVersion"

# 3. Create annotated tag
git tag -a "v$newVersion" -m "Release v$newVersion"

# 4. Push to trigger GitHub Actions workflow
git push origin main
git push origin "v$newVersion"
```

The GitHub Actions release workflow will automatically:
- Build the monolithic script
- Validate all components
- Create GitHub release with artifacts
- Publish to PowerShell Gallery (if configured)

## Release Workflow Overview

### Job 1: Build (`build`)

**Purpose:** Validate configuration, build artifacts, and prepare release notes.

**Steps:**
1. **Extract version from tag** - Parses `v2.1.0` to get version `2.1.0`
2. **Verify manifest version** - Ensures psd1 version matches git tag
3. **Validate module manifest** - Runs `Test-ModuleManifest`
4. **Run PSScriptAnalyzer** - Checks code quality and style
5. **Build monolithic script** - Generates `dist/Optimize-WsusServer.ps1`
6. **Validate built script** - Checks syntax and file integrity
7. **Generate checksums** - SHA256 hashes for both script and manifest
8. **Generate release notes** - Creates markdown documentation
9. **Create module archive** - Zips module files for alternative installation

**Artifacts created:**
- `dist/Optimize-WsusServer.ps1` - Monolithic script (production use)
- `Optimize-WsusServer-Module.zip` - Full module (alternative)
- `release-notes.md` - GitHub release description

### Job 2: Publish to PowerShell Gallery (`publish-gallery`)

**Purpose:** Publish the module to PowerShell Gallery for easy installation.

**Prerequisite:** Configure `NUGET_KEY` secret in GitHub repository settings

**Steps:**
1. **Update module version** - Ensures psd1 version matches release tag
2. **Validate module for gallery** - Performs additional checks
3. **Publish to PowerShell Gallery** - Uses `Publish-Module` cmdlet
4. **Create publish notification** - Provides download links

**Configuration:**
- Only runs if `NUGET_KEY` secret is set
- Safely skips if secret is not configured (no error)
- Supports pre-release versions (e.g., `2.1.0-beta`)

### Job 3: Post-Release Tasks (`post-release`)

**Purpose:** Update repository after successful release.

**Steps:**
1. **Update changelog entry** - Adds entry to `CHANGELOG.md` if it exists
2. **Create version bump commit** - Commits version updates (optional)

**Result:** Clean audit trail of releases in git history

## Version Numbering

Follow **Semantic Versioning** (https://semver.org/):

```
v2.1.0
 │ │ │
 │ │ └─ PATCH (bug fixes): v2.1.0 → v2.1.1
 │ └─── MINOR (features): v2.1.0 → v2.2.0
 └───── MAJOR (breaking): v2.1.0 → v3.0.0
```

### Pre-release versions:
- `v2.1.0-alpha` - Early testing phase
- `v2.1.0-beta` - Feature complete, testing
- `v2.1.0-rc.1` - Release candidate

**Update manifest accordingly:**
```powershell
# For stable release
ModuleVersion = '2.1.0'

# For pre-release
ModuleVersion = '2.1.0'
Prerelease = 'beta'  # Displayed as "2.1.0-beta"
```

## Setup: PowerShell Gallery Publishing

### 1. Create PowerShell Gallery Account

1. Visit https://www.powershellgallery.com/users/account/Register
2. Create account (free)
3. Verify email

### 2. Generate API Key

1. Log in to PowerShell Gallery
2. Go to Account Settings → API Keys
3. Create new key with:
   - Name: `GitHub Actions`
   - Scope: `Publish new packages and package versions`
4. Copy the key (shown once)

### 3. Configure GitHub Secret

1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `NUGET_KEY`
4. Value: Paste the API key from step 2
5. Click "Add secret"

### 4. Verify Configuration

Push a tag to trigger the workflow and confirm publishing succeeds:
- Check GitHub Actions logs for "Successfully published to PowerShell Gallery"
- Verify module appears on PowerShell Gallery: https://www.powershellgallery.com/packages/Optimize-WsusServer/

## Release Checklist

Before creating a release tag:

- [ ] Update `ModuleVersion` in `Optimize-WsusServer.psd1`
- [ ] Update `Prerelease` field if pre-release version
- [ ] Review `CHANGELOG.md` (if using)
- [ ] Ensure all tests pass locally: `Invoke-Pester Tests/`
- [ ] Run `PSScriptAnalyzer` locally: `Invoke-ScriptAnalyzer -Path ./Public, ./Private`
- [ ] Test build locally: `.\Build\Build-MonolithicScript.ps1`
- [ ] Commit changes: `git add Optimize-WsusServer.psd1 && git commit -m "chore(release): prepare vX.Y.Z"`

## Releasing

```powershell
# 1. Create annotated tag
$version = "2.1.0"
git tag -a "v$version" -m "Release v$version"

# 2. Push to trigger workflow
git push origin main
git push origin "v$version"

# 3. Monitor GitHub Actions
# https://github.com/lusoris/Optimize-WsusServer/actions

# 4. Verify on PowerShell Gallery
# https://www.powershellgallery.com/packages/Optimize-WsusServer/
```

## Troubleshooting

### Release workflow fails during build

**Issue:** Workflow shows red ✗ on build job

**Solution:**
1. Check error logs in GitHub Actions
2. Common causes:
   - Manifest version doesn't match tag (e.g., `v2.1.0` tag but psd1 says `2.1.1`)
   - Code fails PSScriptAnalyzer validation
   - Private functions missing from Public/ folder

**Fix:**
1. Update manifest locally
2. Commit and push changes
3. Delete tag: `git tag -d v2.1.0 && git push origin --delete v2.1.0`
4. Create new tag when ready

### Module fails PowerShell Gallery validation

**Issue:** Workflow completes but module not visible on gallery

**Solution:**
1. Check GitHub Actions logs under `publish-gallery` job
2. Common causes:
   - API key invalid or expired
   - Module version already published (must increment version)
   - Manifest has syntax errors

**Fix:**
1. Increment version: `2.1.0` → `2.1.1`
2. Create new release tag: `git tag -a "v2.1.1" -m "Release v2.1.1"`
3. Push: `git push origin "v2.1.1"`

### Want to skip PowerShell Gallery publishing

**Solution:** Delete the `NUGET_KEY` secret from GitHub settings. Workflow will safely skip publishing while still creating GitHub releases.

## Files Modified During Release

The release workflow modifies these files (automatically committed):

1. **Optimize-WsusServer.psd1** - Version bumped to match tag
2. **CHANGELOG.md** - Entry added for release (if file exists)

All changes are automatically committed with message: `chore(release): bump version to vX.Y.Z`

## Rollback / Yanking Release

### If published to PowerShell Gallery

To un-publish a version (mark as deprecated on gallery):

1. Log in to https://www.powershellgallery.com
2. Find the package version
3. Click "Report Abuse" or contact PowerShell Gallery support
4. Provide details that version should be unlisted

### If only GitHub release

Simply delete the tag:
```powershell
git tag -d v2.1.0
git push origin --delete v2.1.0
```

## Best Practices

1. **Commit Message Consistency**
   - Use: `chore(release): prepare v2.1.0`
   - Avoid vague messages like "release" or "update"

2. **Version Increment Order**
   - PATCH (2.1.0 → 2.1.1): bug fixes
   - MINOR (2.1.0 → 2.2.0): new features
   - MAJOR (2.1.0 → 3.0.0): breaking changes

3. **Pre-release Testing**
   - Always test locally first: `Invoke-Pester Tests/`
   - Use pre-release tags for beta/rc testing
   - Example: `v2.1.0-beta.1` → `v2.1.0-beta.2` → `v2.1.0`

4. **Keep CHANGELOG.md**
   - Document user-facing changes
   - Follow Keep a Changelog format: https://keepachangelog.com/
   - Helps users understand what changed

5. **Announce Releases**
   - Tag maintainers in release notes
   - Reference related issues/PRs
   - Include breaking changes prominently

## Release Workflow Diagram

```
Push tag (v2.1.0)
    ↓
┌─────────────────────────────────────────┐
│ Job 1: Build                            │
│ ✓ Validate manifest                     │
│ ✓ Run PSScriptAnalyzer                  │
│ ✓ Build monolithic script               │
│ ✓ Generate release notes                │
└──────────────┬──────────────────────────┘
               ↓
┌──────────────────────────────────────────┐
│ Job 2: Publish to Gallery (optional)     │
│ ✓ Validate for PowerShell Gallery        │
│ ✓ Publish module (if NUGET_KEY set)      │
└──────────────┬───────────────────────────┘
               ↓
┌──────────────────────────────────────────┐
│ Job 3: Post-Release                      │
│ ✓ Update CHANGELOG.md                    │
│ ✓ Create version bump commit             │
└──────────────┬───────────────────────────┘
               ↓
         Release Complete
         GitHub: v2.1.0
         Gallery: Available for install
```

## Additional Resources

- [PowerShell Gallery Publishing Guidelines](https://learn.microsoft.com/en-us/powershell/gallery/publishing-guidelines/publishing-a-module)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

