# Scope: what exists and what the next version changes

**State, 2026-11-19: this repository holds Holdback's phase-one settlement contracts at the fixed version (tag `phase-one-fixed`), which is not deployed. The next contract version has 12 items on record: 5 decided and 7 open. The operators, the API, the adjudicator's models and the website are out of scope.** Labels: **measured** (counted or run on 2026-11-19 from a clean clone of this repository), **documented** (a named document states it), **inferred**, **guessed**.

"Holdback" below is the public repository [rafaeldavid/holdback](https://github.com/rafaeldavid/holdback). A path without it is a path in this repository.

## 1. What exists

### Source

Five files in `contracts/src/`, 1,800 lines in all, comments included [measured, `wc -l`]. 978 of them are code: lines that are not blank and do not start with `//`, `/*` or `*` [measured, a `grep` count; NatSpec counts as comment].

| File | Lines | Code lines | What it is |
| --- | --- | --- | --- |
| `HoldbackRules.sol` | 593 | 378 | The rules contract: funds a hold through the escrow, takes the seller's delivery, the adjudicators' decisions, early accepts, mutual settlements and timeouts, and pays out |
| `HoldbackTypes.sol` | 481 | 358 | The signed types, their EIP-712 hashes and the checks on terms (a library) |
| `IHoldbackRules.sol` | 496 | 111 | The rules contract's interface: types, events, errors, functions and their descriptions |
| `DrandQuicknetBeacon.sol` | 209 | 126 | Verifies a drand quicknet round on chain, with the EIP-2537 BLS12-381 precompiles |
| `IHoldbackBeacon.sol` | 21 | 5 | The beacon's interface |

The contracts call Coinbase's Commerce Payments `AuthCaptureEscrow` and its ERC-3009 collector, which hold the funds (`contracts/lib/commerce-payments`, a submodule, unmodified), and Solady's signature checker [documented: `docs/decisions/ADR-0003-escrow-contract-base.md`, `docs/audit/scope.md`].

### Tests

539 tests in 73 suites: 539 passed, 0 failed, 0 skipped [measured: CI on GitHub's runners, from a clean checkout of this repository, on `main` and on the tag `phase-one-fixed`, 2026-11-19, about 4 to 6 minutes of test time per run].

| Suite | Solidity files | Lines |
| --- | --- | --- |
| `test/unit/` | 43 | 6,776 |
| `test/crosscheck/` | 19 | 3,826 |
| `test/differential/` (the side-by-side harness against the deployed source) | 14 | 3,843 |
| `test/handlers/` and `test/invariant/` | 5 | 2,233 |
| `test/fuzz/` | 2 | 446 |
| `test/attack/` | 3 | 539 |
| All | 86, of which 70 are test files (`*.t.sol`) | 17,663 |

[measured, `find` and `wc -l`]

### Gas and size

Gas was not re-measured for this page. The figures the repository records:

| What | Gas or bytes | Source |
| --- | --- | --- |
| `agreeAndFund`, one transaction | 233,994 gas, measured with `--isolate` on 2026-11-04 | `contracts/test/unit/GasPerDeal.t.sol:18`, which sets a budget of 300,000 [documented] |
| The beacon's pairing check, two pairs | 102,900 gas; the fixed version takes the cap at deployment with this floor | `docs/audit/known-issues.md` RR-1; `docs/audit/outside-scan.md`, change (b) [documented] |
| One `beaconValue` transaction | 219,232 gas, a first figure | `docs/decisions/ADR-0034-settlement-chain-and-mainnet-gate.md`, MG-17 [documented] |
| Each settlement path, as a whole test (setup included, not one transaction) | 323,439 gas (reclaim) to 618,870 gas (a fallback decision with the drand proof) | `contracts/.gas-snapshot`, the `GasPerDeal` rows [documented] |
| `HoldbackRules` runtime size | 4,074 bytes below the EIP-170 limit, measured on the deployed version | holdback `docs/decisions-today.md` D82, citing the readiness review T-499 [documented] |

`cd contracts && forge test --match-path test/unit/GasPerDeal.t.sol --isolate` and `forge build --sizes` measure them again.

### Scripts and records

- `contracts/script/`: the deploy script `deploy-sepolia.sh` and four helper contracts (an open-mint test token, a local USDC, a local Multicall3 and a local beacon), 5 files and 999 lines [measured].
- `contracts/scripts/`: six Node scripts and their configuration for coverage, mutation testing and runtime hashes [measured].
- `contracts/deployments/`: the Sepolia deployment records. The live one is `sepolia.json`.

### Documents

- `docs/audit/`: the scope, threat model, invariants, functions, events, state model, test quality, known issues and engagement pages, and the outside scan with its data (`outside-scan.md`).
- `docs/decisions/`: 13 of holdback's 41 decision records. Why each is here is in [`README.md`](README.md), section 7.

## 2. What the fixed version changed

The fixed version is the deployed version plus six changes in four source files: 76 lines added and 23 removed, comments included [measured in holdback: `git diff --shortstat contracts-phase-one-1 d621291e -- contracts/src`]. Each change and the fix review's verdict on it are in `docs/audit/outside-scan.md`, "The six changes". In short:

- (a) the constructor probes the beacon;
- (b) the beacon's pairing gas is set at deployment, with a floor;
- (c) a call short of gas reverts `NotEnoughGas`;
- (d) funding refuses nonzero dispute fields;
- (e) a primary's decision carries no beacon fields, and an escalation no appeal ground;
- (f) a comment is corrected.

## 3. What the next version must change

One row per item. **Decided** means a decision record or Rafa's recorded words settle what changes. **Open** means the change is named but its shape, or whether it comes, is not settled. The size is given only where a document gives one.

| # | Change | Source | State | Rough size |
| --- | --- | --- | --- | --- |
| 1 | A mutual settlement's signed digest names its signer. Today two contract wallets that accept one shared key can fill both the buyer's and the seller's slot with one signature | `docs/audit/known-issues.md` OS-3; scan finding `3dec9493` (`docs/audit/outside-scan.md`) | **Decided:** accepted as a limit for phase one, and `MutualSettlement` gains the signer's address in the rebuilt contracts (Rafa, 2026-11-18) | Not given. A signed struct changes, so the EIP-712 domain version moves [inferred] |
| 2 | A settlement note's hash gets a named field and an event. Today it rides in the settlement's `nonce` | holdback `docs/decisions-today.md` D78; `docs/decisions/ADR-0039-amend-a-funded-deal.md` §4 | **Open:** the nonce carrier stands for now, and "a named field and an event come later, in a contract version of their own". D78 has four open points | Not given |
| 3 | The contract refuses a carried delivery in any decision that is not an accept | holdback `docs/decisions-today.md` D85; `docs/audit/known-issues.md` OS-1 and OS-2; scan finding `696fcaca` | **Decided** (Rafa, 2026-11-19) | Not given |
| 4 | An escalation's beacon round is fixed by state, not by the block the escalation lands in | D85; `docs/audit/known-issues.md` the BR-6 residual and OS-4; scan finding `8a875efc`; `docs/decisions/ADR-0032-beacon-rounds-escalation-and-fallback.md` alternative I | **Decided** (Rafa, 2026-11-19). Its cost, that an escalation waits for its deadline, is weighed when the version is designed | Not given |
| 5 | The beacon probe's residual is closed, and `triggerFallback` no longer needs the beacon | `docs/audit/known-issues.md` OS-6; scan finding `bf7f2cb1`, new in the fix review | **Open.** The page names a complete fix (a fallback trigger that does not need the beacon) and a partial one (check the code length, decode the round as a `uint64`, refuse the largest value); neither is chosen | Not given |
| 6 | An on-chain signal that an adjudicator cannot open its envelope: a signed message the contract records and the terms can give a consequence | holdback `docs/decisions-today.md` D81 | **Open.** Rafa wants it in the next rebuild; its shape and effect are not decided. It is a protocol step and a signed type, so it needs a decision record and a schema version | Not given |
| 7 | Standing offers through a seller contract beside the rules contract. The rules contract does not change | `docs/decisions/ADR-0040-standing-offers.md`; D82 | **Decided** (Rafa, 2026-11-18 and 2026-11-19). The contract task (T-548 in holdback) was being built on 2026-11-19 [reported] | 5 tasks and about 6 pull requests, the contract itself 1 of them [guessed in ADR-0040 §10]; most of the rest is off-chain |
| 8 | The job events' ID type and names are checked against ERC-8183. The events key on a `bytes32 jobId` [measured: `contracts/src/IHoldbackRules.sol:140`]; two names are not in the draft and two draft events are never emitted | `docs/audit/events.md` E-10 (review I-10); scan finding `d2ee602a` | **Open.** ERC-8183 is a draft; the names are to be settled against its final text | Not given |
| 9 | If the version changes any signed struct, the mandate's typed data changes with it: `categories` and `hasCategories` leave `Scope`, the richer mandate's fields arrive, and the domain and `commitment.schemaVersion` move to 0.9 | holdback `docs/decisions/ADR-0038-mandate-limits-and-revocation.md` §5 and step 8 | **Decided** as the plan (adopted under the repository's autonomy rule; nothing built). The mandate is checked off chain; the contracts move with the domain | "Large: every signed vector and recording moves" (ADR-0038, step 8) |
| 10 | Party appeals and adjudicator bonds | holdback `docs/decisions-today.md` D57; `docs/decisions/ADR-0031-phase-one-contract-scope.md` SC-7; `docs/decisions/ADR-0007-bonded-adjudicators-liveness.md` | **Open.** Phase one leaves them out, and the first decision is final on chain. When they return is Rafa's call. The contracts deployed on 2026-11-04 (domain 0.7) have them (`docs/audit/known-issues.md`, opening section), and the side-by-side harness keeps their source in `contracts/test/differential/old/` | Not given |
| 11 | The mainnet gate: 39 conditions before any deploy to Ethereum mainnet, 15 of them on the contracts (group C, MG-9 to MG-22 and MG-37) | `docs/decisions/ADR-0034-settlement-chain-and-mainnet-gate.md` §7 | **Open** as to timing. The conditions are recorded (status Proposed); Rafa, 2026-11-11: "We can deal with this later" | Not given. MG-9 needs an audit by an outside firm, closed with its fix review |
| 12 | Smaller items a next version may take: refuse high-`s` signatures (RR-4); refund at once when `triggerFallback` comes at or after `fallbackBy` (RR-5); the phase-one-only types that ADR-0031 lists as candidates (`appealWindowSec` 0 among them) | `docs/audit/known-issues.md` RR-4 and RR-5; ADR-0031, "Signed types and schemas" | **Open.** Each is accepted or documented today, with the change named as an option | Not given |

Count: 12 items, 5 decided (1, 3, 4, 7, 9) and 7 open (2, 5, 6, 8, 10, 11, 12).

## 4. Out of scope

- **The operators and the REST API** (holdback `apps/operator`, `packages/`). They relay signed messages and keep no custody. Contract changes move their EVM adapter (`OPEN-QUESTIONS.md`, question 3).
- **The adjudicator's service and its models** (holdback `apps/adjudicator`): the judgment pipeline, the panel of pinned models, its defenses.
- **The website and the agents' documents** (holdback `site/`).
- **Spend controls,** a separate protocol with its own repository. Holdback does not call it.
- **The escrow itself:** Coinbase's Commerce Payments contracts, which the rules contract uses unmodified.
- **Real money.** Sepolia test tokens only, until the mainnet gate is passed.
