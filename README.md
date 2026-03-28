# Blood on the Clocktower — Storyteller Companion

A standalone SwiftUI iOS app that helps storytellers run Blood on the Clocktower games. Handles script selection, player setup, secret role assignment, night/day phase tracking, voting, and game-over detection — all with a bilingual English/Chinese interface.

## Screenshots

*(Coming soon)*

## Supported Editions

| Edition | Status |
|---------|--------|
| **Trouble Brewing** | Roughly tested — includes experimental roles with no known bugs so far. 53 unit tests and deterministic trace tests cover core role interactions. |
| **Bad Moon Rising** | Playable but under active development. Some role interactions have known bugs. |
| **Sects & Violets** | Playable but under active development. Some role interactions have known bugs. |

Bad Moon Rising and Sects & Violets updates are still under development and will be released soon.

## Features

- **Script selection** for three official base editions plus optional experimental role toggles
- **Player setup** with configurable player count (5–20) and automatic team distribution
- **Secret role assignment** with flip-card reveal UI — hand the device around the table
- **Imp bluff panel** shown to the Demon player during assignment
- **Night phases** with role-ordered wake queue and storyteller-assisted action prompts
- **Day phases** with nomination, voting (Butler master restriction, ghost votes), and execution
- **Storyteller tools**: flexible registration overrides, misinformation-flagged logs, poison tracking
- **Game-over detection**: no Demon alive, evil majority, Saint executed, Mayor survived, and more
- **127 role icons** covering all three base scripts and experimental roles
- **Bilingual UI**: English and Simplified Chinese throughout
- **Day timer** with configurable duration and pause/resume

## Requirements

- **Xcode 26+** with Swift 5.0 and iOS Simulator support
- **macOS 26** (Tahoe) or later
- **iOS 26.2+** deployment target
- Apple Developer Program membership ($99/year) if publishing to the App Store

## Getting Started

1. Clone the repository.
2. Open `blood_on_the_clocktower.xcodeproj` in Xcode.
3. Select the `blood_on_the_clocktower` scheme and an iPhone simulator.
4. Build and run (Cmd+R).

### App Flow

1. Choose an edition.
2. Enable any experimental-role options you want.
3. Enter player names and generate the setup.
4. Hand the device around for secret role assignment.
5. Run the game through the built-in night/day tracker.

## Running Tests

```bash
xcodebuild test \
  -project blood_on_the_clocktower.xcodeproj \
  -scheme blood_on_the_clocktower \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Replace `iPhone 17 Pro` with any available simulator if your local list differs.

## Project Layout

```
blood_on_the_clocktower/
├── blood_on_the_clocktower/
│   ├── Views/              # SwiftUI views (ContentView, GameFlowView, etc.)
│   ├── ViewModels/         # Game state and logic
│   ├── Models/             # Core enums and data structures
│   ├── Components/         # Reusable UI components
│   ├── Data/               # JSON script data and loader
│   └── Assets.xcassets/    # App icon, role icons, card backs
├── blood_on_the_clocktowerTests/       # Unit and trace tests
├── blood_on_the_clocktowerUITests/     # UI tests (scaffolded)
└── .github/workflows/                  # CI/CD pipelines
```

## CI/CD

The project includes GitHub Actions workflows:

- **CI** (`ci.yml`): SwiftLint (strict) → Build → Test with code coverage and artifact upload. Runs on every push and PR to main.
- **Archive** (`archive.yml`): Builds a Release archive on version tags (`v*`). Uploads the `.xcarchive` as an artifact.
- **Release Drafter** (`release-drafter.yml`): Auto-generates draft release notes from merged PR titles.
- **Dependabot** (`dependabot.yml`): Keeps GitHub Actions versions up to date weekly.

## License

MIT — see [LICENSE](LICENSE) for details.

## Disclaimer

Blood on the Clocktower is a trademark of The Pandemonium Institute. This is an unofficial fan-made companion app and is not affiliated with or endorsed by The Pandemonium Institute.
