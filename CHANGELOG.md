# Changelog

All notable changes to this community fork of Powerlevel10k.

## [Unreleased]

### Fixed
- **swap**: Add FreeBSD/BSD support using `sysctl vm.swap_total`/`vm.swap_reserved` with `swapinfo` fallback
- **ram (free)**: Replace fragile `/var/run/dmesg.boot` parsing with real-time `sysctl` on FreeBSD

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
