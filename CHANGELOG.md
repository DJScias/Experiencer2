# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add support to have reputation bars use the current standing color.
    - Can be enabled with `Use reputation color` in `Frame Options` (adds [#4](https://github.com/DJScias/Experiencer2/issues/4)).
- Add support for threads of the WoW: Remix's `Cloak of Infinite Potential`.
    - Tracks amount of total threads (and amount gained per session).
    - Track remaining necessary threads for next "Infinite Power" level.

## [5.2.6] - 2024-05-07

### Changed

- TOC bump.
- Changelog Updates (again.. oops!).

## [5.2.5] - 2024-04-13

### Changed

- Update friendship tier colors for Cobalt Assembly and Soridormi (Time Rifts).
- Update friendship tier colors for Sabellian/Wrathion.
- Condensed 5 tier friendships together (they behave the same way color-wise).

## [5.2.4] - 2024-04-07

### Fixed

- 10.2.6 deprecates `IsRecruitAFriendLinked`, use `C_RecruitAFriend.IsRecruitAFriendLinked` instead to avoid errors throwing.

## [5.2.3] - 2024-03-20

### Changed

- TOC bump.

## [5.2.2] - 2024-01-16

### Changed

- Color picker updates (frame was overhauled and now includes a hex color input field).

## [5.2.1] - 2024-01-16

### Changed

- TOC bump.

## [5.2.0] - 2023-11-18

### Added

- Paragon support for Renown reputations (fixes [#2](https://github.com/DJScias/Experiencer2/issues/2)).

### Fixed

- Fix reputations prior to DF showing Exalted when they are actually Paragon.
- Potentially fix right-click error due to missing semicolon (fixes [#1](https://github.com/DJScias/Experiencer2/issues/1)).

### Changed

- Updated libraries.

## [5.1.2] - 2023-11-08

### Changed

- TOC bump.

## [5.1.1] - 2023-10-23

### Changed

- Proper version bump.

## [5.1.0] - 2023-10-23

### Added

- Support for friendship reputation colors (Tillers, Sabellian/Wrathion, Cobalt Assembly, etc..)

## [5.0.0] - 2023-11-18

### Added

- New GitHub (https://github.com/DJScias/Experiencer2) due to original owner quiting WoW.
- Renown can be tracked.
- Friendships can be tracked (Tillers, Sabellian/Wrathion, etc..)

### Fixed

- Right-click watch faction works again.