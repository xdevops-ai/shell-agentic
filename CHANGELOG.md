# Changelog

All notable changes to the OpsBot binaries distributed from this repository are
documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-10-14

First public binary release.

### Added

- Prebuilt, statically linked `opsbot` binaries for Linux (amd64, arm64) and
  macOS (amd64 / Intel, arm64 / Apple silicon), published as
  `opsbot_2.0.0_<os>_<arch>.tar.gz` with a `SHA256SUMS` file.
- `install.sh` installer with OS/architecture detection and SHA-256
  verification.
- Bash wrapper with a real PTY: interactive tools (`vim`, `tmux`, `ssh`, ...)
  behave as in a normal terminal.
- Connection to your dedicated XDevOps tenant over WebSocket with mutual TLS
  (client certificate from the XDevOps portal), automatic reconnect every 3
  seconds, and an online/offline indicator in the prompt.
- Shortcuts: `Ctrl+E` / `^^` (ask), `Ctrl+S` (share recent output),
  `Ctrl+T` (toggle auto-analysis), `Ctrl+O` (help).
- Local regex-based redaction of shared terminal output (configurable via
  `REDACT_PATTERNS`).
- Local audit log (`opsbot_audit.log`) and debug log (`opsbot_debug.log`).

[2.0.0]: https://github.com/xdevops-ai/shell-agentic/releases/tag/v2.0.0
