# Security Policy

This repository uses a small, pragmatic security policy for dependency upgrades and securing the project.

## High-level policy
- We treat high/critical vulnerabilities as a blocking issue on CI and close any PR that introduces them without action.
- For moderate/low vulnerabilities where the fix requires a breaking upgrade (e.g., Vue 2 -> Vue 3), we create an explicit migration branch and maintain both versions until the migration completes.

## Reporting vulnerabilities
- Please report vulnerabilities via GitHub issues or security advisories on the repo.

## Maintainership
- The `maintainers` team should review Dependabot PRs weekly and apply minor/patch updates automatically.
- Major updates must include a migration plan and QA validation.

## Emergency remediation
- If a production critical vulnerability is discovered, open a security issue and update the repo immediately with the mitigation steps.
