# Snapshot: phase-one-fixed

This commit is a copy of files from the public repository [rafaeldavid/holdback](https://github.com/rafaeldavid/holdback). It has no history of its own. Every path keeps its place in holdback, so relative links and the tests' paths still work.

| Path here | Copied from holdback | Tree or blob hash |
| --- | --- | --- |
| `contracts/` (sources, tests, scripts, deployment records, `.gas-snapshot`) | commit `d621291eb4f57d7c4b3cdae71bf7c6310b822a9e`, on the branch `contracts-audit-ready` | `contracts/src` tree `c4edcfb1185a34f5a205d9170e0ae690c758c157` |
| `contracts/lib/commerce-payments` | a git submodule at holdback's commit, from `https://github.com/base/commerce-payments` | commit `6b0a5ef3f0df973857f558e2d6b5dd645b5e97f9` |
| `fixtures/beacon/` (real drand rounds the beacon tests read) | commit `d621291e` | tree `40b1c8abb9bd79b25cb944241d10d64f1716973f` |
| `packages/settlement/evm/accepted-tokens.json` (the token table `contracts/script/deploy-sepolia.sh` reads) | commit `d621291e` | blob `2f44a7356a0b4b7c3229b0cb0df4b77c2b4919ae` |
| `LICENSE`, `.gitmodules` | commit `d621291e` | as in holdback |
| `docs/audit/` except the outside scan | commit `941ccbd0`, the tip of `contracts-audit-ready` on 2026-11-19, whose `contracts/src` is this version | as in holdback |
| `docs/audit/outside-scan.md` and `docs/audit/outside-scan/` (the published scan, the fix review and their data) | commit `d9da8a00` on holdback's `main` | as in holdback |
| `docs/decisions/` (13 of holdback's 41 decision records) | commit `d9da8a00` | as in holdback |

Added here, not in holdback: this file, `.gitignore`, `.gitleaks.toml` (three false positives allowed, each named) and `.github/workflows/ci.yml`.

This version is the deployed version plus six changes in four source files. An outside firm's automated fix review read it on 2026-11-19 (`docs/audit/outside-scan.md`). **It is not deployed.** The contracts live on Ethereum Sepolia are the earlier version, tag `contracts-phase-one-1` in holdback (commit `27ab44e8`), and run with test tokens only. The deployment records in `contracts/deployments/` describe that earlier deployment; they are the same files at both commits.

Links in the copied pages to holdback files not copied here (task files, reviews, research, the operator code) resolve in the public holdback repository at the same path.
