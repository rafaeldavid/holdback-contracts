# The audit engagement

This page is the note an outside audit's terms point to: what the auditor reads, what is excluded, and what comes back. Rafa decided the plan on 2026-11-17 (D77 in [`docs/decisions-today.md`](../decisions-today.md)). Start the reading itself at [`README.md`](README.md).

## What to audit

- **The code:** `contracts/src/` at the git tag `contracts-phase-one-1`. These five files are deployed on Sepolia and verified on Sourcify. [`README.md`](README.md) lists them with their line counts, the commit and the addresses; [`scope.md`](scope.md) lists what is out of scope and why.
- **The docs:** `docs/audit/` on `main`, from the merge of holdback PR 613 (`418b111`) onwards. They correct the copies at the code tag; the code on `main` equals the tag's.
- **The code does not change during the audit.** Fixes land in the next build, not in the code under review (D77).

## What is excluded

- **Every row of [`known-issues.md`](known-issues.md).** Crow found these itself: the accepted limits, the phase-one cuts and the review's RR-1 to RR-5 (section 10). Do not report a listed issue as a new finding. Say so where you rate a listed issue higher than the page does, or where its stated bound does not hold.
- **The dependencies,** relied on unchanged: Commerce Payments' `AuthCaptureEscrow` and `ERC3009PaymentCollector`, Solady, OpenZeppelin, Multicall3 ([`scope.md`](scope.md), "Third-party code"). How `HoldbackRules` uses them is in scope.
- **What a token issuer can do to its own token** (freeze, pause, blacklist).
- **Everything off chain:** the operator API, the adjudicator service, the judgment pipeline, the site and the test tokens.

## Where to look hardest

Each is a place where a defect would move held funds outside the signed terms:

1. **Signatures.** EIP-712 hashes against `packages/core` (`Vectors.t.sol`), ERC-1271 signers in every role, and replay across deals, deployments and chains.
2. **The escrow's operator.** Every `authorize`, `capture`, `void` and the buyer's own reclaim on the escrow, and the escrow's expiry against the deal's deadlines.
3. **Deadlines and stages.** Each timeout opens exactly at its deadline, and nothing settles twice.
4. **The drand verifier.** `DrandQuicknetBeacon.sol` and the rounds the rules contract asks it for.
5. **The phase-one cuts.** Party appeals, bonds, Permit2 and third-party payouts were removed (ADR-0031). Check that no removal left a path open.

## What comes back

- **One report,** with each finding's severity, the file and line at the tag, how to reproduce it (a Foundry test where possible) and the smallest fix.
- **In the template's shape where it fits:** the public worked example is [`spec/examples/commitment.audit-report.example.json`](../../spec/examples/commitment.audit-report.example.json). The deal's terms say which of its checks apply.
- **Delivered through the deal:** the audit is a Crow deal, paid through Crow's own escrow in test tokens on Sepolia. The terms set the price, the delivery deadline and the acceptance checks.

## Contact

- **Questions during the audit:** the repository owner, `rafaeldavid` on GitHub, or the channel the deal names.
- **A vulnerability outside this scope:** GitHub's private vulnerability reporting ([`SECURITY.md`](../../SECURITY.md)).
