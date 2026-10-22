# Native release process

Swift is the only active app implementation. Electron source is archived under `legacy/electron/`; no release workflow runs npm or Electron.

## Executors

- `Native CI and Release` runs complete native tests and an ad-hoc app build on GitHub's `macos-26` runner. Trusted main-branch changes also run headless tests on a dedicated Mac mini runner.
- The Mac mini runner must be registered to this repository with labels `self-hosted`, `macOS`, `ARM64`, `macmini`, `stash`. It uses its own installation directory and must not reconfigure an existing runner for another repository.
- Pull requests use GitHub-hosted runners. The persistent Mac mini never runs pull-request code.
- The packaging stage follows the complete native tests and builds Apple Silicon on `macos-26` and Intel on `macos-26-intel`. The build requires Swift 6.2+ and macOS SDK 26+ so the Liquid Glass implementation is compiled into both packages.

The machine's FileVault remains enabled. A user LaunchAgent runs after that user logs in; it does not imply unattended recovery after arbitrary power loss.

## Credentials

The repository already provides these secret names:

- `APPLE_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`: base64 PKCS#12 containing a Developer ID Application identity.
- `APPLE_API_KEY_CONTENT`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`: base64 App Store Connect API private key and its identifiers for Apple notarization.
- `TENCENT_SECRET_ID`, `TENCENT_SECRET_KEY`, `COS_BUCKET`, `COS_REGION`: release-artifact COS access.

Signing uses a temporary keychain on disposable GitHub runners. Cleanup restores the previous keychain search list and removes the certificate/key files. Credentials are not copied to the Mac mini.

## Verify and publish

1. Update `swift/Scripts/Info.plist` and add `docs/releases/<version>.md`.
2. Run `make test`, `make build` and `make release` locally. The default release mode produces ad-hoc ZIP/DMG validation packages; these must not be distributed as a public release.
3. Push main and confirm both native CI jobs succeed. A manual `Native CI and Release` run with mode `verify` exercises the architecture matrix without public uploads.
4. Push `v<version>` after validation. The tag must match Info.plist. The workflow builds and signs the native app, notarizes/staples the app and DMG, verifies the executable architecture and signature, and emits per-architecture SHA-256 manifests.
5. The publish job requires both architectures and the Mac mini test gate, and verifies that the version tag points to the tested commit before any public upload. It validates the manifests, uploads the versioned packages and `SHA256SUMS` to COS, downloads the public CDN bytes and compares their hashes, then creates the GitHub Release with native assets.

Paths are case-sensitive:

```
https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-arm64.dmg
https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-arm64.zip
https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-x64.dmg
https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-x64.zip
```

The native updater queries `buggyblues/Stash` GitHub Releases and selects the matching architecture's native ZIP. Electron's `latest-mac.yml` and blockmaps are not used in 2.x.

After publication, verify the installed app's version and `StashImplementation=swift`, open it from Applications, and verify website copy, images and direct download URLs on the actual production site. A successful build alone is not release acceptance.
