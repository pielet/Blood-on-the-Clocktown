# Blood on the Clocktower

Standalone SwiftUI iOS app for running a Blood on the Clocktower game. The project includes script selection, player setup, secret role assignment, guided game flow, bilingual English and Chinese UI text, and automated tests around core Trouble Brewing behavior.

## Features

- Script selection for the official base editions: Trouble Brewing, Bad Moon Rising, and Sects and Violets
- Optional experimental-role toggles during setup
- Player setup and role deck generation
- Secret assignment flow for handing roles to players one at a time
- Night and day game flow tracking with timers, logs, and action records
- English and Simplified Chinese interface text
- Unit and trace tests for key gameplay logic

## Project Layout

- `blood_on_the_clocktower.xcodeproj`: Xcode project for the app and test targets
- `blood_on_the_clocktower/`: app source, assets, view models, and script data
- `blood_on_the_clocktowerTests/`: unit and trace tests
- `blood_on_the_clocktowerUITests/`: UI tests

## Requirements

- A recent version of Xcode with Swift and iOS simulator support
- macOS for local development and simulator testing

## Getting Started

1. Open `blood_on_the_clocktower.xcodeproj` in Xcode.
2. Select the `blood_on_the_clocktower` app target or scheme.
3. Choose an iPhone simulator.
4. Build and run the app.

From there, the app flow is:

1. Choose an edition.
2. Enable any experimental-role options you want.
3. Enter players and generate the setup.
4. Hand the device around for secret role assignment.
5. Run the game through the built-in night/day tracker.

## Running Tests

Run the test targets from Xcode, or use `xcodebuild` from this directory:

```bash
xcodebuild test \
  -project blood_on_the_clocktower.xcodeproj \
  -scheme blood_on_the_clocktower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If your local simulator list differs, replace `iPhone 17 Pro` with any available simulator device.

## CI/CD

The project includes GitHub Actions workflows:

- **CI** (`ci.yml`): SwiftLint (strict) → Build → Test with code coverage and artifact upload. Runs on every push and PR to main.
- **Archive** (`archive.yml`): Builds a Release archive on version tags (`v*`). Uploads the `.xcarchive` as an artifact.
- **Release Drafter** (`release-drafter.yml`): Auto-generates draft release notes from merged PR titles.
- **Dependabot** (`dependabot.yml`): Keeps GitHub Actions versions up to date weekly.

### Recommended Branch Protection

After pushing to GitHub, enable these rules under Settings > Branches > main:

1. Require a pull request before merging.
2. Require status checks to pass (select the `SwiftLint`, `Build`, and `Test` checks).
3. Require branches to be up to date before merging.
4. Optionally require conversation resolution.

## Git Notes

This folder is intended to work as its own standalone repository. The local `.gitignore` excludes Xcode user state, build products, and other machine-specific files so the repo only tracks project source, assets, and test code.
