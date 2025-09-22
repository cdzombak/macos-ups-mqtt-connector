# Code Signing and Notarization Setup

This document describes the required secrets and setup steps for code signing and notarization of releases.

## Required GitHub Secrets

The following secrets must be added to the repository settings:

### Code Signing Secrets
- `DEVID_SIGNING_CERT`: Base64-encoded Developer ID Application certificate (.p12 file)
- `DEVID_SIGNING_CERT_PASS`: Password for the Developer ID certificate
- `DEVID_SIGNING_CERT_ID`: Certificate identifier (SHA-1 fingerprint)
- `KEYCHAIN_PASS`: Password for the temporary keychain (can be any secure random string)

### Notarization Secrets
- `NOTARIZATION_APPLE_ID`: Apple ID email address
- `NOTARIZATION_TEAM_ID`: Apple Developer Team ID
- `NOTARIZATION_PASS`: App-specific password for notarization

## Setup Instructions

### 1. Export Developer ID Certificate
1. Open Keychain Access on your Mac
2. Find your "Developer ID Application" certificate
3. Right-click and select "Export"
4. Save as .p12 format with a password
5. Convert to base64: `base64 -i certificate.p12 | pbcopy`
6. Add the base64 string as `DEVID_SIGNING_CERT` secret

### 2. Get Certificate ID
1. In Keychain Access, double-click your Developer ID certificate
2. Copy the SHA-1 fingerprint (remove spaces)
3. Add as `DEVID_SIGNING_CERT_ID` secret

### 3. Create App-Specific Password
1. Go to https://appleid.apple.com/account/manage
2. Sign in with your Apple ID
3. Generate an app-specific password for "notarization"
4. Add as `NOTARIZATION_PASS` secret

### 4. Get Team ID
1. Go to https://developer.apple.com/account/
2. Find your Team ID in the membership details
3. Add as `NOTARIZATION_TEAM_ID` secret

## Testing

### Local Testing
To test code signing locally:
```bash
make build
codesign --verify --verbose ./out/macos-ups-mqtt-connector-<version>
```

### CI Testing
1. Create a test release tag: `git tag v0.0.1-test && git push origin v0.0.1-test`
2. Monitor the GitHub Actions workflow
3. Verify the release includes both .tar.gz and .dmg files
4. Download and test the .dmg file on a clean Mac

### Verification Commands
```bash
# Verify code signature
codesign --verify --verbose /path/to/binary

# Check notarization status
spctl --assess --verbose /path/to/binary

# Verify DMG
hdiutil verify /path/to/file.dmg
```
