# Changelog

All notable changes to this project will be documented in this file.  
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.5.2] - 2026-02-18
More fixes in regards to secrets (mainly combat-related).

### Fixed  
- Fix secret-related issue in regards to reputations in combat.  
- Fix another secret-related issue in regards to pause (AFK) check for experience in combat.  

## [6.5.1] - 2026-02-18
Small hotfix update for the second Midnight pre-patch, fixing a secret error related to pausing (AFK).

### Fixed  
- Handle secret-related pause (AFK) check for experience in combat [#21](https://github.com/DJScias/Experiencer2/issues/21)).  

## [6.5.0] - 2026-01-20
First update for Midnight to make sure it handles the combat restrictions put in place.  
House XP tracker bar is planned sooner or later, but allowing Experiencer to work in Midnight is a priority.  

### Added  
- Add support for hiding the default Blizzard status tracking bar (Experience, Reputation, etc).

### Changed  
- 12.0.0 TOC bump.
- Deferred addon logic where required to happen after combat to avoid Midnight's restrictions.

## [6.4.1] - 2025-12-03

### Changed  
- 11.2.7 TOC bump.

## [6.4.0] - 2025-10-16

### Added  
- Add support for Infinite Power of Legion Remix.  
    - Tracks amount of total Infinite Power (and amount gained per session).  
    - Track remaining necessary Infinite Power for next "Unlimited Power" achievement level.  

### Changed  
- `Threads` option has been re-enabled with new tracking for Legion Remix.  
- 11.2.5 TOC bump.

## [6.3.7] - 2025-08-06

### Changed  
- 11.2.0 TOC bump.

## [6.3.6] - 2025-06-17

### Changed  
- 11.1.7 TOC bump.

## [6.3.5] - 2025-04-22

### Changed  
- 11.1.5 TOC bump.

## [6.3.4] - 2025-02-25

### Added  
- 11.1.0 TOC addon list category (Quests) and group (Experiencer2).  
  - This puts Experiencer2 into the right Category (and Group) for 11.1's addon list.

### Changed  
- 11.1.0 TOC bump.

## [6.3.3] - 2024-12-18

### Changed  
- 11.0.7 TOC bump.

## [6.3.2] - 2024-10-22

### Changed  
- 11.0.5 TOC bump.

## [6.3.1] - 2024-10-16

### Changed  
- Optimize ExperiencerModuleBarsMixin:TriggerBufferedUpdate.

### Fixed  
- Safeguard reputation GetBarData being nil (fixes [#17](https://github.com/DJScias/Experiencer2/issues/17)).  
  - Thanks to Github user NoShotz for helping track this down.  
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

## Older Changelogs  
These can always be found on the [Experiencer 2.0's GitHub Wiki](https://github.com/DJScias/Experiencer2/wiki/Experiencer-2.0-%E2%80%90-Changelog).
