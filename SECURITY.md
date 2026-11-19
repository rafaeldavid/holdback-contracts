# Security policy

**This repository is a read-only copy of Holdback's contracts. Report a vulnerability through the holdback repository, where the code is maintained.** The contracts run on Ethereum Sepolia with test tokens only.

## Report a vulnerability

Report privately through GitHub's private vulnerability reporting on the holdback repository: open https://github.com/rafaeldavid/holdback/security/advisories/new. You need a GitHub account. Do not open a public issue or pull request for a suspected vulnerability, here or in holdback.

1. Name the affected contract and commit. The contract source here is holdback commit `d621291e`. The deployed version is holdback tag `contracts-phase-one-1`, commit `27ab44e8`.
2. Give the steps to reproduce, with a proof of concept if you have one.
3. Say the impact you expect.

Write in English. Holdback's own [`SECURITY.md`](https://github.com/rafaeldavid/holdback/blob/main/SECURITY.md) gives the response times, the scope and the safe harbor, and they apply here.

## Before you report

`docs/audit/known-issues.md` and `docs/audit/outside-scan.md` list the issues already known, with their status. A report of a listed issue helps most when it shows a harm the listing does not state.

## Out of scope

- Contracts reused unchanged: Coinbase's Commerce Payments `AuthCaptureEscrow` and its ERC-3009 collector, Multicall3, and the libraries under `contracts/lib/`. Report those to their maintainers.
- Controls a token issuer holds over its own token.
- The value of test tokens, which have none.

## Status

No audit by human reviewers has run. Two automated reviews by an outside firm are recorded in `docs/audit/outside-scan.md`, with three Informational findings open. There is no bug bounty.
