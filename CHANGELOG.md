# Changelog

All notable changes to this community fork of Powerlevel10k.

## [v1.24.8] - 2026-02-23

### Fixed
- **instant_prompt_date**: Force `LC_TIME=C` during instant prompt date stash expansion to prevent localized day/month names (consistent with time segment fix for #2871)

### Added
- **tests**: Add unit tests for disk_usage segment (df parsing, threshold logic, ONLY_WARNING mode)
- **tests**: Add unit tests for instant_prompt_date locale handling

## [v1.24.7] - 2026-02-22

### Fixed
- **todo**: Add 5-second timeout to `todo.sh` command to prevent prompt hangs on network-backed storage

### Added
- **tests**: Add unit tests for SHOW_ON_COMMAND menu-select skip logic (#2912)
- **tests**: Add unit tests for todo.sh output parsing and timeout handling

## [v1.24.6] - 2026-02-22

### Fixed
- **aws_eb_env**: Add 10-second timeout to `eb list` to prevent prompt hangs on network issues
- **taskwarrior**: Add 5-second timeout to all `task` CLI calls (`show`, `count`, `list`) to prevent prompt hangs on lock contention or data issues

### Added
- **tests**: Add timeout validation tests for eb list and taskwarrior commands

## [v1.24.5] - 2026-02-22

### Added
- **transient_prompt**: Add `POWERLEVEL9K_TRANSIENT_PROMPT_SHOW_EXECUTION_TIME` option to display command execution time in transient prompt (#2913)
- **tests**: Add unit tests for haskell_stack resolver parsing (#2890), UTF-8 pattern matching (#2887), IP interface regex (#2900)
- **tests**: Add unit tests for instant prompt locale handling (#2871)
- **tests**: Add `test/run_all.zsh` test runner

### Fixed
- **instant_prompt**: Force `LC_TIME=C` during instant prompt time stash expansion to prevent brief flash of localized AM/PM strings (#2871)
- **wizard**: Add `cat` fallback for `cp` in configuration wizard to handle restrictive filesystem permissions (e.g., sticky-bit /tmp) (#2896)

## [v1.24.4] - 2026-02-22

### Fixed
- **wifi**: Add secondary SSID fallback using `ipconfig getsummary` + `listpreferredwirelessnetworks` for macOS 15+ when `getairportnetwork` also returns redacted (#2894)
- **nordvpn**: Add 5-second timeout to `nordvpn status` CLI call to prevent async worker hangs (#2860)
- **haskell_stack**: Add 10-second timeout to `stack query` fallback to prevent long prompt delays (#2890)

## [v1.24.3] - 2026-02-21

### Fixed
- **time**: Force `LC_TIME=C` in realtime time segment to prevent localized AM/PM strings (e.g., 午前/午後 in Japanese) (#2871)
- **date**: Force `LC_TIME=C` in date segment to prevent localized day/month names, consistent with time segment fix (#2871)

## [v1.24.2] - 2026-02-21

### Fixed
- **nordvpn**: Rewrite segment to use `nordvpn status` CLI instead of raw socket protocol, fixing shell freeze with newer NordVPN versions (#2860)
- **cpu_usage, ram_usage**: Add missing `reset=1` to async output, ensuring prompt redraws when usage state changes (HIGH/MEDIUM/LOW transitions)
- **swap**: Add FreeBSD/BSD support using `sysctl vm.swap_total`/`vm.swap_reserved` with `swapinfo` fallback
- **ram (free)**: Replace fragile `/var/run/dmesg.boot` parsing with real-time `sysctl` on FreeBSD

### Improved
- **nordvpn**: Move CLI invocation to async worker to avoid blocking prompt rendering
- **haskell_stack**: Parse GHC version directly from `stack.yaml` for `ghc-*` resolvers, avoiding slow `stack` invocation (#2890)

## [v1.24.1] - 2026-02-20

### Fixed
- **cpu_usage, ram_usage**: Add FreeBSD support
- **docker_context**: Fix init for podman/nerdctl, improve DOCKER_HOST parsing

## [v1.24.0] - 2026-02-20

### Added
- **ram_usage**: New prompt segment for RAM usage percentage with HIGH/MEDIUM/LOW thresholds
- **docker_context**: Add podman and nerdctl to `SHOW_ON_COMMAND`

### Fixed
- **docker_context**: Improve DOCKER_CONFIG and DOCKER_HOST support, fix JSON regex

## [v1.23.1] - 2026-02-19

### Fixed
- Auto-disable instant prompt for AI coding agents (Cursor, Copilot, Windsurf) (#2865)
- Resolve 'bad pattern' errors when `extended_glob` is off (#2887)
- Use `getairportnetwork` for macOS SSID fallback
- Restore SVN branch display in `vcs_info`, add bold support for VCS styles
- Allow SVN/HG vcs_info when multiple VCS backends are configured (#2889)
- Handle macOS 15+ redacted SSID in wifi segment (#2894)
- Skip prompt updates during menu-select to preserve completion menu (#2912)
- Add `--no-run-setup` to haskell_stack to prevent side effects (#2890)
- Harden `_p9k_on_expand` locale check against missing `extended_glob`

### Added
- Bridge interface support to default IP_INTERFACE pattern (#2900)
- 'same-dir' transient prompt option to wizard (#2880)
- Troubleshooting docs for AI coding agents

## [v1.23.0] - 2026-02-19

### Added
- **cpu_usage**: System CPU usage percentage segment with HIGH/MEDIUM/LOW color thresholds
- **docker_context**: Active Docker context prompt segment
- Enhanced transient prompt with time/status display (#9)
- Show last error code only once (#11)
- Respect explicit `LEFT_SEGMENT_END_SEPARATOR` for copy-friendly prompts (#12)
- `root_indicator` and `ssh` to config templates

### Fixed
- Reset text attributes after `prompt_char` to prevent bleeding into output (#3)
- Tab-completion, resize, bad pattern, NordVPN hang issues (#2, #4, #5, #6)
- Tab completion 'bad pattern' error and `cp -p` failure on sticky-bit dirs
- AM/PM locale issue (#2871), DIR_ANCHOR_BACKGROUND (#2874)

## [v1.21.0] - 2026-02-19

Initial community fork release based on romkatv/powerlevel10k.

### Added
- Troubleshooting note for slanted/round separator glitches (#1)
- MAINTAINERS.md

[Unreleased]: https://github.com/redbasecap-buiss/powerlevel10k/compare/v1.24.1...HEAD
[v1.24.1]: https://github.com/redbasecap-buiss/powerlevel10k/compare/v1.24.0...v1.24.1
[v1.24.0]: https://github.com/redbasecap-buiss/powerlevel10k/compare/v1.23.1...v1.24.0
[v1.23.1]: https://github.com/redbasecap-buiss/powerlevel10k/compare/v1.23.0...v1.23.1
[v1.23.0]: https://github.com/redbasecap-buiss/powerlevel10k/compare/v1.21.0...v1.23.0
[v1.21.0]: https://github.com/redbasecap-buiss/powerlevel10k/releases/tag/v1.21.0
