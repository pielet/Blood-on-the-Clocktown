# Publishing Guide

## Version Strategy

Use [Semantic Versioning](https://semver.org/):

- **1.0.0** — First release: Trouble Brewing, Bad Moon Rising, Sects & Violets with storyteller flow, night/day turns, voting, and bilingual UI.
- **1.x.0** — New editions, experimental role expansions, or major UI additions.
- **1.x.y** — Bug fixes, balance tweaks, localization corrections.

Set the version in Xcode under the target's General tab (Marketing Version and Current Project Version), or edit `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the `.xcodeproj/project.pbxproj` file directly.

## Pre-Release Checklist

1. All tests pass: `xcodebuild test -scheme blood_on_the_clocktower -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:blood_on_the_clocktowerTests`
2. SwiftLint clean: `swiftlint lint --strict`
3. CI pipeline green on main branch (lint, build, test).
4. No force-unwrap warnings outside test helpers.
5. Both English and Chinese strings reviewed for new or changed UI.
6. App icon and launch screen assets present in Assets.xcassets.
7. Role icons present for every role in all three base scripts plus experimentals.

## TestFlight (Recommended First Step)

TestFlight is the easiest way to share the app with a small group before a public App Store release.

1. Create an **App Store Connect** record at https://appstoreconnect.apple.com.
2. In Xcode: Product > Archive (with a real device or "Any iOS Device" destination).
3. In the Organizer window, click "Distribute App" > "App Store Connect" > Upload.
4. In App Store Connect, add internal testers (up to 100) or create a public TestFlight link.
5. Testers install via the TestFlight app.

Advantages: no App Store review needed for internal testers, crash reports and feedback built in.

## App Store Release

1. Complete all fields in App Store Connect: description, keywords, screenshots (6.7" and 5.5" at minimum), privacy policy URL, and age rating.
2. For screenshots, run the app on iPhone 17 Pro Max simulator and use Cmd+S in Simulator to capture.
3. Submit for review. First review typically takes 1-3 days.
4. After approval, release manually or set an automatic release date.

### App Store Requirements

- **Bundle ID**: Must be unique (e.g., `com.yourname.clocktower-storyteller`).
- **Signing**: Requires an Apple Developer Program membership ($99/year).
- **Privacy**: The app collects no user data. Select "No data collected" in App Store Connect.
- **Content Rating**: Board game companion, no objectionable content. Set the questionnaire accordingly.

## Alternative Distribution

### Ad Hoc / Direct Install

For small groups without TestFlight:

1. Archive in Xcode.
2. Distribute App > Ad Hoc.
3. Share the `.ipa` file. Recipients need their device UDID registered in your developer portal.

### Open Source / Build From Source

If publishing the source on GitHub:

1. Add a `LICENSE` file (MIT or similar).
2. Ensure the README covers build prerequisites (Xcode version, simulator requirements).
3. Contributors can clone, open in Xcode, and run directly on Simulator.

## CI/CD Enhancements to Consider

The current workflow covers lint, build, and test. Future additions:

- **Automatic archiving**: Add an `archive` job on tagged commits to produce an `.xcarchive` artifact.
- **TestFlight upload**: Use `xcrun altool` or the App Store Connect API to upload builds automatically on version tags.
- **Code coverage reporting**: Add `-enableCodeCoverage YES` to the test step and upload the report.
- **Dependabot**: Enable for GitHub Actions version updates.
- **Branch protection**: Require CI to pass before merging PRs to main.
- **Release drafter**: Use `release-drafter` GitHub Action to auto-generate release notes from PR titles.

## Git Tagging for Releases

```bash
# Tag the release
git tag -a v1.0.0 -m "First release: three base scripts, storyteller flow, bilingual UI"
git push origin v1.0.0
```

Then create a GitHub Release from the tag with a changelog summary.

## Changelog Format

Keep a `CHANGELOG.md` or use GitHub Releases. Group entries by:

- **Added** — new features or roles
- **Changed** — behavior changes
- **Fixed** — bug fixes
- **Removed** — deprecated features

## Version History

| Version | Date       | Notes |
|---------|------------|-------|
| 1.0.0   | 2026-03-25 | First version. Trouble Brewing fully debugged and tested. Bad Moon Rising, Sects & Violets, and experimental roles included but have known bugs — gameplay logic for those editions is still under active debugging. Bilingual EN/ZH UI. 53 unit + trace tests covering Trouble Brewing. |
