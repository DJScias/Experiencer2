# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Nil-guard potential bar data, ref #17

## [6.3.1] - 2024-10-16

### Changed
- Optimize ExperiencerModuleBarsMixin:TriggerBufferedUpdate.

### Fixed
- Safeguard reputation GetBarData being nil (fixes [#17](https://github.com/DJScias/Experiencer2/issues/17)).
- Safeguard ExperiencerModuleBarsMixin:Refresh against potential nil data values.
- Safeguard ExperiencerModuleBarsMixin:TriggerBufferedUpdate against potential nil data values.

## [6.3.0] - 2024-09-22

### Added
- Reputation now has a "Wait for end of combat" option, this is off by default.
    - It waits to handle all reputation calculations until after all combat is over.
		- Potentially mitigates freezing/lag when farming lots of reputation-giving mobs consistently.

### Changed
- Fall clean-up, a lot of code has been rewritten and optimized. In most cases, this should have no noticeable end-user changes.

### Fixed
- Safeguard GetFactionInfoByName (previously GetFactionIDByName) factionData being nil (fixes [#16](https://github.com/DJScias/Experiencer2/issues/16)).

## [6.2.1] - 2024-09-10

### Changed
- Updated some reputation colors (mainly friendships that don't stick by the normal reputation namings).
    - From my checks, they seem to all be using the "friendly" green color for every rank. Please report if different of course!

### Fixed
- Fix reputation `CanLevelUp`, `C_Reputation.GetFactionParagonInfo` does not return a data struct, so `hasRewardPending` retrieval failed.
    - Should fix [#12](https://github.com/DJScias/Experiencer2/issues/12).

## [6.2.0] - 2024-09-07

### Added
- Add two new options introduced to reputations in The War Within (also found in the upper right corner on the reputations panel):
    - "Reputation Filter" lets you filter your reputations between All, Warband and your Character.
	- "Show Legacy Reputation" toggles all the reputations prior to The War Within.

### Changed
- Rewrote the behavior of "Auto add to Recent Reputations list" and "Auto switch bar to last gained reputation".
    - Auto-add has no noticeable end-user changes that are worth mentioning.
	- Auto switch now works correctly even if "auto add" is not checked.
		- However, it will always add the switched reputation to Recent Reputations, regardless of the "auto add" setting.
    - Should completely fix [#10](https://github.com/DJScias/Experiencer2/issues/10), thanks to Github users Demonicka and JBabbb for helping track this down.

## [6.1.9] - 2024-09-07

### Changed
- Rewrote the reputation list coding. This should work a bit more straightforward and solves some quirks.
    - For example: Brann Bronzebread being part of "The Severed Threads" (which he's not last I checked).

### Fixed
- Nil check for `factionData` in `GetFactionActive`.

## [6.1.8] - 2024-09-06

### Fixed
- Warband (Account-Wide) reputation gains were not properly counted and auto-switching did not work as a result (fully fixes [#10](https://github.com/DJScias/Experiencer2/issues/10)).

## [6.1.7] - 2024-09-05

### Fixed
- Auto-switching reputation from no tracked reputation could caues issues (fixes [#10](https://github.com/DJScias/Experiencer2/issues/10)).

## [6.1.6] - 2024-08-23

### Fixed
- Workaround reputation issue when encountering broken/empty/duplicate TWW headers.
    - This seems to be perhaps an early TWW issue?

## [6.1.5] - 2024-08-22

### Changed
- Updated the Experience code, plus some general clean-up.
    - Added Guild Banner Standards and Draught of Ten Lands as EXP modifiers.
	- Potential fix for updating expansion level (only on xpac change).

### Fixed
- LibSharedMedia-3.0 libraries were loaded wrongly - again.
- Removed a leaky global (no end-user changes).

## [6.1.4] - 2024-08-21

### Added
- Added WoWInterface to the BigWigs Packager.

### Changed
- `Cloak Threads` option has been disabled with the end of World of Warcraft Remix: Mists of Pandaria.
    - The bar will display "no cloak" and can be switched away from, but it can no longer be selected in the menu.
- `Font face` dropdown now scrolls instead of being multiple `More` dropdowns (11.0.2 fixed this).

## [6.1.3] - 2024-08-17

### Fixed
- LibSharedMedia-3.0 libraries were loaded wrongly.

## [6.1.2] - 2024-08-16

### Fixed
- BigWigs Packager's .pkgmeta was ignoring the libraries wrongly.

## [6.1.1] - 2024-08-16

### Added
- BigWigs Packager to both CurseForge and Wago.io.

## [6.1.0] - 2024-08-15

### Added

- Add reputation option "Clear recent reputations":
    - This will clear your recent reputations list in case it has grown too considerably.

### Changed

- TOC bump.
- Rework the Watched Faction and Recent Reputations menus.
    - This has no tangible end-user changes.

### Fixed

- Feed correct data into recent reputations list (fixes [#9](https://github.com/DJScias/Experiencer2/issues/9)).
- Fix errors regarding retrieving artifact info (Heart of Azeroth).

## Older Changelogs
These can always be found on the [Experiencer 2.0's GitHub Wiki](https://github.com/DJScias/Experiencer2/wiki/Experiencer-2.0-%E2%80%90-Changelog).