# Repository Instructions

## Mandatory release synchronization

Any product change intended for release is complete only after all three destinations are synchronized:

1. **GitHub:** validate the change, commit it, and push `main` to `origin`.
2. **Update server:** build the installer, publish it in `/opt/df-booster` as `DeltaForceBooster-Setup.exe`, then publish `build/update-manifest.json` there as `update-manifest.json`. Always publish the installer before the manifest and verify the public file size, SHA256, and version.
3. **Official website:** add the release notes to the changelog in `website/index.html`, publish it as `/opt/df-booster/index.html`, then verify `https://df.ltz88.cn/` displays the new version, release notes, and download link.

If credentials or connectivity block any destination, report the release as incomplete and name the exact blocker. Do not describe a release as complete when only GitHub has been updated.

## Public release-note policy

Public changelogs, update manifests, and GitHub Release notes must not mention the internal admin dashboard or data dashboard. Release notes should describe only user-facing changes.
