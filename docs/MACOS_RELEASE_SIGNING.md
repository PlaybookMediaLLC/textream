# macOS release signing

Public DMG and app ZIP releases require a Developer ID Application certificate with its private key and Apple notarization credentials. The release workflow fails before building when credentials are missing. A Team ID and bundle ID do not contain a signing key.

## Create the signing certificate

1. Sign in to [Apple Developer certificates](https://developer.apple.com/account/resources/certificates/list) as the Account Holder for Team `T44K9669GA`.
2. If a Developer ID Application certificate already exists, export it with its private key from the Mac that created it. Downloading its `.cer` alone does not recover the private key. Do not revoke certificates used by other apps.
3. Otherwise, use Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority. Enter your email and a key name, leave CA Email Address empty, and save the request to disk.
4. In Apple's certificate portal, add a **Developer ID Application** certificate, upload the request, and download the `.cer`.
5. Install the certificate on the Mac that created the request. Export the certificate and private key from Keychain Access > My Certificates as a password-protected `.p12`. The identity name follows the Apple account's legal name; it need not match the GitHub organization name.

Apple's [Developer ID guide](https://developer.apple.com/help/account/certificates/create-developer-id-certificates) and [certificate request guide](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/) describe these steps.

## Configure GitHub Actions secrets

Use [this repository's Actions secrets](https://github.com/PlaybookMediaLLC/textream/settings/secrets/actions). Keep keys and passwords out of source files, chat, and command-line arguments. Upload the certificate through standard input, and enter passwords at the hidden prompts:

```bash
base64 -i /path/to/developer-id.p12 | gh secret set MACOS_CERT_P12_BASE64 -R PlaybookMediaLLC/textream
gh secret set MACOS_CERT_PASSWORD -R PlaybookMediaLLC/textream
```

For notarization, configure **one** complete method:

| Method | Required secrets |
| --- | --- |
| Apple Account | `APPLE_ID`, `APPLE_APP_PASSWORD` |
| App Store Connect team API key | `APPLE_NOTARY_KEY_BASE64`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID` |

The Apple Account method defaults to Team `T44K9669GA`; `APPLE_TEAM_ID` can override it. `MACOS_SIGNING_IDENTITY` is optional when the imported keychain has one Developer ID Application identity. A complete API key configuration takes precedence over Apple Account credentials.

For the Apple Account method, open [account.apple.com](https://account.apple.com), choose Sign-In and Security > App-Specific Passwords, and generate a password named `Dante GitHub Releases`. Two-factor authentication is required. Store the generated password as `APPLE_APP_PASSWORD`, not your normal Apple Account password:

```bash
gh secret set APPLE_ID -R PlaybookMediaLLC/textream
gh secret set APPLE_APP_PASSWORD -R PlaybookMediaLLC/textream
```

Apple documents [app-specific passwords](https://support.apple.com/en-us/102654). Changing the main account password revokes existing app-specific passwords.

## Validate a release

Run the shell regression checks before pushing:

```bash
python3 -B -m unittest discover -s tests -p 'test_release_signing.py' -v
shellcheck Textream/build.sh
actionlint .github/workflows/release.yml
```

The regression checks use fake Apple tools to test control flow. They do not prove real signing, Apple acceptance, or Gatekeeper acceptance.

The release build uses `REQUIRE_NOTARIZATION=1`. It signs nested frameworks and the app with hardened runtime and timestamps, notarizes the app ZIP, requires an `Accepted` response, and staples and assesses the app before copying it into the DMG. It then signs, notarizes, staples, validates, and assesses the DMG. Any failed check stops artifact publication. Local `./Textream/build.sh` builds can still use ad-hoc signing for development.

After a successful release run, download the actual DMG and app ZIP. Validate the DMG ticket and Gatekeeper assessment, mount it, and validate the contained app. Also validate the app extracted from the published ZIP:

```bash
xcrun stapler validate /path/to/Dante-for-Creators-macOS-universal.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 /path/to/Dante-for-Creators-macOS-universal.dmg
codesign --verify --deep --strict --verbose=2 /path/to/Dante.app
xcrun stapler validate /path/to/Dante.app
spctl --assess --type execute --verbose=2 /path/to/Dante.app
```

Test the browser-downloaded app on a clean Mac with normal Gatekeeper settings, including an offline first launch. Do not remove download quarantine to make a release test pass. Apple's normal first-launch confirmation may still appear for notarized apps.

The App Store `.xcarchive.zip` assets are unsigned CI archives; this Developer ID flow does not sign or submit them for the App Store. Re-running semantic-release without a releasable commit does not necessarily create a new version or replace existing release assets.
