# Open questions about the next contract version

**State, 2026-11-19: 19 questions about building the next contract version. 8 are open and Rafa's to decide, and 11 are answered in a named document.** "Holdback" below is the public repository [rafaeldavid/holdback](https://github.com/rafaeldavid/holdback); a path without it is a path in this repository.

## Open, Rafa's to decide

| # | Question | What the documents say so far |
| --- | --- | --- |
| 1 | Is the next version the phase-one design with the rows of [`SCOPE.md`](SCOPE.md), section 3, or a rebuilt contract set? | D77 calls the build after the fixed version "the rebuilt contracts" and names no scope for it (holdback `docs/decisions-today.md`, D77) |
| 2 | Which open rows go into it: the settlement note's field, the envelope signal, a fallback that does not need the beacon, the ERC-8183 alignment, party appeals and bonds? | Each row's source in `SCOPE.md` says what is decided |
| 3 | Which off-chain changes ship with it: the EVM adapter, the operators, SimChain, the API schemas and the signed vectors? | A change to a signed struct moves code outside this repository: `contracts/test/unit/Vectors.t.sol` pins the EIP-712 hashes against holdback's `packages/core` |
| 4 | When does an audit by human reviewers run, and on which commit? | The mainnet gate asks for an audit closed with its fix review (ADR-0034 §7, MG-9). None has run (`docs/audit/known-issues.md`, G-6) |
| 5 | Does the TLA+ model of the state machine change with it? | The model is in holdback `formal/`, not copied here |
| 6 | Who deploys it, and who holds the deployer key? | The script is `contracts/script/deploy-sepolia.sh`. On mainnet the key holds gas only and has no power after the deploy (ADR-0034 §7, MG-22) |
| 7 | Are the open points of ADR-0039 (changing a funded deal) settled before the note's field is designed? | D78 has four open points (holdback `docs/decisions-today.md`, D78) |
| 8 | Do party appeals and bonds come back in the next version or later? | Phase one leaves them out (D57; `docs/decisions/ADR-0031-phase-one-contract-scope.md` SC-7) |

## Answered in a document

| # | Question | Answer, and where |
| --- | --- | --- |
| 9 | Which chain? | Sepolia now. Ethereum mainnet is the first mainnet, and an L2 comes later; Rafa decided the order (`docs/decisions/ADR-0034-settlement-chain-and-mainnet-gate.md` §2). Real money waits for the gate's 39 conditions (§7) |
| 10 | May a contract have an owner, a pause or an upgrade proxy? | No. "Settlement contracts have no owner, pause, freeze, blacklist or upgrade proxy" (holdback `CLAUDE.md`, hard rules). `contracts/test/fuzz/NoAdmin.fuzz.t.sol` checks the function list |
| 11 | What must every change pass? | Three tests: neutrality, the hold, and defended judgment (`docs/decisions/ADR-0001-neutrality-litmus-test.md`, `ADR-0002-custody-on-neutral-settlement.md`; holdback `CLAUDE.md`, litmus tests) |
| 12 | How are amounts and rates written? | Amounts in token base units, as integers. Rates in basis points or as a numerator and denominator. No float in any hashed body (holdback `CLAUDE.md`, hard rules; ADR-0022 in holdback) |
| 13 | What does custody rest on? | Coinbase's Commerce Payments `AuthCaptureEscrow` and its ERC-3009 collector, unmodified, as a submodule (`docs/decisions/ADR-0003-escrow-contract-base.md`; ADR-0034 §3.4) |
| 14 | How many tokens, and which funding paths? | One token per deployment, and ERC-3009 funding only (ADR-0031 SC-1 and SC-2) |
| 15 | How does a new version reach the chain? | As a new deployment. The deployed contracts cannot be changed, and deals opened on an older deployment finish there (`docs/audit/outside-scan.md`; `docs/audit/known-issues.md`, opening section) |
| 16 | Must the rules contract change for standing offers? | No. A seller contract goes beside it (`docs/decisions/ADR-0040-standing-offers.md` §8) |
| 17 | Which toolchain? | Foundry v1.0.0, solc 0.8.28, EVM version prague (for the EIP-2537 precompiles), and the IR pipeline (`contracts/foundry.toml`, `contracts/README.md`) |
| 18 | What test depth is expected? | Unit tests per entry point, fuzz tests, handler invariants, red-team attacks, a side-by-side harness against the deployed source, and mutation testing (`contracts/README.md`; `docs/audit/test-quality.md`) |
| 19 | Under what licence is the code? | Apache License 2.0 (`LICENSE`) |
