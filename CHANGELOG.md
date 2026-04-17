# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Bad Moon Rising: fix remaining role interaction bugs (Zombuul, Pukka, Shabaloth, Po demons; Godfather, Devil's Advocate, Assassin, Mastermind minions; Gambler, Gossip, Professor).
- Sects & Violets: fix remaining role interaction bugs (Fang Gu jump, Vigormortis/No Dashii neighbor poisoning, Vortox false-info enforcement; Pit-Hag, Cerenovus, Witch).
- Expanded test coverage for Bad Moon Rising and Sects & Violets editions.
- UI test implementation.

## [1.0.1] - 2026-04-17

### Fixed

- Empath auto-calculation now correctly counts only alive neighbors when woken up. Previously, pending demon kill targets were still counted as alive.
- Duplicate passive-info summary text no longer appears above the Complete/Skip buttons during night actions.

### Changed

- Night kills (Demon, Godfather, Shabaloth, Po) now resolve immediately when the Storyteller completes the step, instead of being deferred to dawn. This ensures all subsequent night roles see accurate alive/dead state.
- Recluse/Spy role name is now shown alongside the player name in alignment registration prompts (Chef pairs, Empath neighbors, Fortune Teller, Virgin nomination, etc.) so the Storyteller can see why the choice is needed.
- Split `ClocktowerGameViewModel` extensions by responsibility: extracted `+PoisonDrunk`, `+PlayerStatus`, `+Death`, `+LogCodecs` from the monolithic `+Helpers` and `+Localization` files.
- Removed `pendingNightKill`, `pendingForcedDemonKills`, `pendingForcedNightKills` deferred-kill variables (replaced by immediate resolution).

## [1.0.0] - 2026-03-28

### Fixed

- Poisoner poison now persists through the following day until dusk, matching official rules ("poisoned tonight and tomorrow day"). Previously cleared at dawn.
- Poisoner death now ends existing poison immediately (checks Poisoner alive).
- Poisoner poison now still persists correctly if the Poisoner becomes the Imp after an Imp self-kill.
- Poisoned Ravenkeeper can now be shown a storyteller-chosen false role, and that false role is logged correctly.
- Scarlet Woman correctly gets priority when exactly 5 players are alive before Imp self-kill (off-by-one in alive count).
- Slayer can now kill the Recluse if the storyteller chooses Demon registration (flexible registration prompt added).
- Poisoned Slayer shot correctly fails during the day (poison persists through day).
- Butler vote is now canceled immediately if the Butler's master cancels their vote.
- Librarian can now select Drunk correctly when Spy is in play, including Drunk registration fallback behavior.
- Night queue no longer keeps actor-died-tonight steps around for players who were already dead from previous nights.

### Added

- Storyteller prompt when Slayer targets a Recluse: choose whether Recluse registers as Demon.
- Persistent poison status indicator for Poisoner targets ("Poisoned by Poisoner (until dusk)").
- Additional regression coverage for Poisoner day persistence, Poisoner dusk expiry, Poisoner death clearing poison, Poisoner-to-Imp poison carryover, poisoned Ravenkeeper false-role logging, Scarlet Woman 5-alive threshold, Slayer vs Recluse (both outcomes), poisoned Slayer during day, Butler vote cancelation, and poisoned info-log coloring in the grimoire.
- Trace tests now handle Imp replacement selection, Slayer Recluse prompts, and Virgin registration prompts.
- Pre-commit hook: blocks large files, gitignored files, and merge conflict markers.
- PR template for standardized pull request descriptions.

### Changed

- `run_blood.sh`: removed broken `run_logic_dry_run` reference, auto-detects simulator when none specified.
- `.gitignore`: added `*.xcresult`, `*.xcarchive`, `__pycache__/`, generated image directories.
- Dark-mode contrast and visibility improved across setup, grimoire, wake-order flow, Imp bluff screens, role assignment cards, and the Finished phase.
- Grimoire rows now expand from the full player card, and role icons are slightly larger in both the grimoire and Finished phase.
- Role assignment layout was tightened so a 3x3 card grid fits more reliably without scrolling.
- Keyboard dismissal now works when tapping outside fields or scrolling in setup / game flow screens.
- Grimoire info-log coloring now matches the event log for poison/drunk misinformation cases instead of being inferred only from role names in the text.

## [0.1.0] - 2025-03-25

### Added

- Script selection for Trouble Brewing, Bad Moon Rising, and Sects & Violets.
- Optional experimental role toggles for each edition.
- Player setup with configurable player count (5–20).
- Role deck building with automatic team distribution (Baron outsider shift, Vigormortis reduction, Fang Gu extra outsider, etc.).
- Secret role assignment flow with flip-card reveal UI.
- Imp bluff setup panel for Demon players.
- First night and subsequent night phases with role-ordered wake queue.
- Day phase with nomination, voting (Butler master restriction, ghost votes), and execution.
- Storyteller-assisted night actions: target selection, info-role results, flexible registration overrides.
- Poisoner suppression with misinformation-flagged logs for info roles.
- Drunk shown-role mechanics: fake Townsfolk identity with false night info.
- Monk protection, Soldier survival, Slayer day-action, Virgin trigger.
- Scarlet Woman demon succession at 5+ alive players.
- Imp self-kill with Minion promotion.
- Saint execution loss, Mayor no-execution win.
- Evil Twin pair setup blocking immediate good win when Demon dies.
- Fortune Teller red-herring selection.
- Moonchild death-trigger target choice.
- Banshee double-nomination after Demon kill.
- Cult Leader alignment flip and alternate win condition.
- Fearmonger chosen-target execution win.
- Legion only-evil-votes-don't-count mechanic.
- Game-over detection: no demons alive, evil population lead, saint executed, mayor survived.
- Bilingual UI: English and Simplified Chinese throughout.
- Day timer with configurable duration and pause/resume.
- Game log with timestamped events and misinformation markers.
- Night action records for storyteller reference.
- 127 role icon assets covering all three base scripts and experimental roles.
- 53 unit tests and 50-seed deterministic trace tests for Trouble Brewing.
- CI pipeline: SwiftLint (strict), build, test with artifact upload.
- Dependabot for GitHub Actions version updates.
- Release drafter for automatic changelog generation from PRs.
- Archive workflow for tagged releases.

### Known Issues

- Bad Moon Rising: gameplay logic has known bugs in several role interactions. Tests pending.
- Sects & Violets: gameplay logic has known bugs in several role interactions. Tests pending.
- Experimental roles: many are storyteller-resolved or manual. Automated logic coverage is partial.
- UI tests are scaffolded but not yet implemented.
