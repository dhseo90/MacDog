# Security Policy

MacDog reads local Codex usage metadata and macOS system state. It must never read, print, cache, or commit Codex auth tokens, refresh tokens, cookies, or session material.

## Supported Versions

MacDog is pre-1.0. Security fixes target the current `main` branch and the latest GitHub Release candidate.

## Reporting A Vulnerability

Please do not open a public issue with secrets, tokens, private logs, or unreleased exploit details.

For now, report privately to the repository owner. Include:

- affected commit or release
- macOS version
- whether the issue involves Codex usage, helper privileges, battery charge limits, release packaging, or GitHub Actions
- minimal reproduction steps without secrets

## Sensitive Data Rules

- Do not read or paste `~/.codex/auth.json`.
- Do not store access tokens, refresh tokens, cookies, session IDs, or authorization headers in cache files, logs, fixtures, screenshots, issues, or PRs.
- Redact raw app-server responses before attaching diagnostics.
- Treat helper install logs and macOS permission prompts as user-environment data.

## Public Repository Guardrails

Before making the repository public:

- run `./script/verify_public_repo_guardrails.sh`
- review `./script/configure_github_public_repo_settings.sh --check`
- enable vulnerability alerts
- enable Dependabot security updates
- apply `main` branch protection with required checks `static-gates` and `guardrails`
- keep GitHub Actions workflow token permissions read-only
- keep GitHub Actions PR review approval disabled
