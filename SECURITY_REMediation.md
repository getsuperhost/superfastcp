## Summary of current vulnerabilities

We ran `npm audit` and found 9 Node package vulnerabilities (low/moderate severity) as of the date of the audit.

### Detected items and recommended actions

1. `@vue/component-compiler-utils` (moderate) — fix requires upgrading `vue-loader` to v17 (Vue 3) -> requires Vue 3 migration. Action: track via migration branch.
2. `postcss` (moderate, nested) — fix requires `vue-loader` 17+ (major) -> plan a Vue 3+ migration.
3. `vue` (low, ReDoS) — fix available only via Vue 3 -> optional migration.
4. `vue-loader` (moderate) — fix available by upgrading to v17 -> major migration.
5. `vue-loading-overlay` (low) — v6 (major) supports Vue 3. Action: keep on Vue 2-compatible release, add to migration plan.
6. `vue-template-compiler` (moderate) — fix available via compiler SFC (Vue 3) -> migration required.
7. `vuex` (low) — fix available via Vuex 4 (Vue 3) -> migration required.
8. `webpack-dev-server` (moderate) — transitive vulnerability via laravel-mix -> fix not available without replacing or updating `laravel-mix`; monitor or migrate to Vite.
9. `laravel-mix` (moderate) — `fixAvailable` false; consider evaluating alternatives (e.g. Vite) or follow upstream patch.

### Mitigation & policy
- For **development-only** vulnerabilities (e.g., `webpack-dev-server`), we accept them if they are not used in production. CI will detect high/critical vulns and block merging.
- For **vulnerabilities requiring a major migration** (Vue 3): create a migration branch, perform necessary code changes, and update major dependencies in that branch with tests and manual UI verification.
- For **fixes available without major changes**, apply minor/patch upgrades and verify builds/tests in CI.

### Next steps and responsibilities
1. Add CI to block high/critical vulnerabilities (done). If an automatic fix exists without breaking changes (e.g., minor version), we can apply it and test.
2. Create a migration branch `feat/migrate-vue3` with the following steps:
   - Upgrade `vue` -> 3.x, `vue-loader` -> 17.x, `vuex` -> 4.x, `vue-router` -> v4; update components to Vue 3 syntax; replace `new Vue()` with `createApp()`.
   - Update `vue-loading-overlay`, `vue-template-compiler` to Vue 3 equivalents (if needed) or replace them.
   - Replace or update `laravel-mix` to one that supports `webpack-dev-server` >= 5.3.x or migrate to Vite.
3. Review `security` PRs (dependabot) and evaluate them individually.

### Minimal immediate fixes applied
- Reverted forced package upgrades that broke Vue 2 compatibility (so the app builds). These are documented in `package.json` and `DEVELOPMENT.md`.
- Added `CI` workflow to enforce `npm audit` fails on high/critical vulnerabilities.
