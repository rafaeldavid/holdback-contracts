# Holdback contracts

**State, 2026-11-19: this repository holds one version of Holdback's phase-one settlement contracts, the fixed version, with their tests, deploy script, audit pages and the decision records behind them. It is a read-only copy made from the public repository [rafaeldavid/holdback](https://github.com/rafaeldavid/holdback), where development happens. The fixed version is not deployed. An outside firm's automated fix review read it on 2026-11-19, and three Informational findings stay open. No audit by human reviewers has run.**

Holdback is the protocol behind Crow, escrow for AI agents. A buyer funds a hold, the seller delivers, adjudicators the two parties named decide acceptance, and the hold is released or refunded. The contracts run on Ethereum Sepolia with test tokens only.

Start with [`SCOPE.md`](SCOPE.md), which covers what exists and what the next version must change, then [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md).

Labels: **measured** (run or counted on 2026-11-19), **documented** (a named document states it), **inferred**.

## 1. The version here

| | |
| --- | --- |
| Tag | `phase-one-fixed`: one commit, a copy of holdback's files with no history ([`SNAPSHOT.md`](SNAPSHOT.md) lists every source) |
| Contract source | holdback commit `d621291eb4f57d7c4b3cdae71bf7c6310b822a9e`, on holdback's branch `contracts-audit-ready` |
| What it is | The deployed version plus six changes in four source files, which answer an outside scan's findings (`docs/audit/outside-scan.md`, "The six changes") |
| Deployed | No |
| `main` | The tag, plus this page, the scope page, the questions page and later edits to them. `contracts/src` on `main` stays equal to the tag; CI fails if it changes |

## 2. What is deployed, and where

The contracts live on Ethereum Sepolia (chain ID 11155111) are the earlier, deployed version: holdback tag `contracts-phase-one-1`, commit `27ab44e8`, deployed on 2026-11-13 [documented: `contracts/deployments/sepolia.json`, fields `chainId`, `deployedAt`]. The record's `commit` field names `938c3fc6`, whose `contracts/src` is the same tree as the tag's, `9c1b2e54` [measured in holdback]. The record holds every address, the compiler settings and the deploy checks.

The deployed contracts have no owner and cannot be changed. The fixed version will be a new deployment.

## 3. Build and test

Prerequisite: Foundry `v1.0.0`, the version CI installs.

```bash
git clone <this repository>
git -C holdback-contracts submodule update --init --depth 1 contracts/lib/commerce-payments
git -C holdback-contracts/contracts/lib/commerce-payments submodule update --init --depth 1 lib/forge-std lib/permit2 lib/solady lib/spend-permissions
git -C holdback-contracts/contracts/lib/commerce-payments/lib/spend-permissions submodule update --init --depth 1 lib/openzeppelin-contracts
cd holdback-contracts/contracts && forge build && forge test
```

Do not pass `--recursive`. It clones about 100 nested test dependencies of Commerce Payments and has hung CI for more than 40 minutes [documented: `contracts/README.md`].

Result: 539 tests in 73 suites, 539 passed, 0 failed and 0 skipped [measured: CI from a clean checkout of this repository, on `main` and on the tag, 2026-11-19]. A build with the IR pipeline takes several minutes.

`contracts/README.md` describes each suite. Its section on TypeScript tests that need anvil refers to holdback's code, which is not copied here.

## 4. What was reviewed, and what stays open

- **An automated scan** by Zero Cool, a security firm, read the five source files of the deployed version (`27ab44e8`) on 2026-11-18. It reported 69 findings: 9 Medium, 9 Low and 51 Informational, none Critical or High. 65 were already in Crow's own records [documented: `docs/audit/outside-scan.md`].
- **An automated fix review** by the same firm read the six changes at `d621291e`, the version here, on 2026-11-19. Five changes close their findings. The sixth, the beacon probe, closes its finding in part, and the review found one new Informational finding [documented: the same page].
- **Open after both:** three Informational findings, `696fcaca`, `8a875efc` and `bf7f2cb1`. The first two stay known limits in phase one, and the next version fixes both (holdback D85). The third is open (`docs/audit/known-issues.md`, OS-6).
- **Crow's own reviews:** the audit pages record them, with Slither 0.11.6 and Aderyn 0.6.8 runs (`docs/audit/functions.md`, `docs/audit/README.md`).
- **Not done:** an audit by human reviewers. Neither automated review is one, and nothing here says the contracts are secure.

The raw data of both reviews, redacted, is in `docs/audit/outside-scan/`.

## 5. Fidelity proof

Each row compares a git tree hash in this repository with the same path in holdback. Equal tree hashes mean byte-identical files, modes and names.

| Path | Here, at `phase-one-fixed` | Holdback | Equal |
| --- | --- | --- | --- |
| `contracts/src` | `c4edcfb1185a34f5a205d9170e0ae690c758c157` | `d621291e:contracts/src` = `c4edcfb1185a34f5a205d9170e0ae690c758c157` | yes [measured] |
| `contracts` (sources, tests, scripts, records, the submodule pointer) | `f3554b93841b61498ecd37f6bd63085361106aca` | `d621291e:contracts` = `f3554b93841b61498ecd37f6bd63085361106aca` | yes [measured] |
| `contracts/lib/commerce-payments` (submodule commit) | `6b0a5ef3f0df973857f558e2d6b5dd645b5e97f9` | the same at `d621291e` and at `27ab44e8` | yes [measured] |
| `fixtures/beacon` | `40b1c8abb9bd79b25cb944241d10d64f1716973f` | the same at `d621291e` | yes [measured] |

To check it yourself, with holdback cloned beside this repository:

```bash
git -C holdback-contracts rev-parse phase-one-fixed:contracts/src
```

```bash
git -C holdback rev-parse d621291e:contracts/src
```

**Against the deployed version.** The deployed tree is `27ab44e8:contracts/src` = `9c1b2e54bcbfd2d5ade7beac8b1cb74f0656815a` in holdback. `git -C holdback diff --stat contracts-phase-one-1 d621291e -- contracts/src` shows the diff the fix review read: four files (`DrandQuicknetBeacon.sol`, `HoldbackRules.sol`, `HoldbackTypes.sol`, `IHoldbackRules.sol`), 76 lines added and 23 removed [measured].

## 6. What is in this repository

| Path | Holds |
| --- | --- |
| `contracts/` | The Foundry project: `src/` (the five files in scope), `test/`, `script/` (the deploy script), `scripts/` (coverage and mutation tooling), `deployments/` (the Sepolia records), `lib/commerce-payments` (a submodule) |
| `fixtures/beacon/` | Real drand quicknet rounds that the beacon tests read, at the path `foundry.toml` grants |
| `packages/settlement/evm/accepted-tokens.json` | The token table `contracts/script/deploy-sepolia.sh` reads, at the path it reads it from |
| `docs/audit/` | The audit pages for this version, and the outside scan's page and data |
| `docs/decisions/` | 13 decision records (section 7) |
| `SNAPSHOT.md` | Where every file came from |

Links in the copied pages to holdback files not copied here, such as task files, reviews, research and the operator code, resolve in the public holdback repository at the same path.

## 7. The decision records here, and why

These 13 of holdback's 41 records bear on the contracts. The rest cover the API, the judgment pipeline, privacy, funding services and process. They are public in holdback `docs/decisions/`.

| Record | Why it is here |
| --- | --- |
| ADR-0001 neutrality | The first test every change must pass: no single party can stop a valid deal or move held funds outside its terms |
| ADR-0002 custody | The hold: funds locked so neither party can take them alone |
| ADR-0003 escrow base | Why the rules contract drives Commerce Payments' escrow, and the ERC-8183-shaped events |
| ADR-0007 bonded adjudicators | The bonds that phase one leaves out and a later version may bring back |
| ADR-0018 panel seed | Why the beacon exists: the panel's seed by commit-reveal and a public randomness round |
| ADR-0019 mutual settlement | The settlement both parties sign, which next-version item 1 changes |
| ADR-0029 delivery binding | How a delivery binds to the deal, which next-version item 3 touches |
| ADR-0031 phase-one scope | What the phase-one contracts do and leave out, with its red team |
| ADR-0032 beacon rounds | The escalation and fallback rounds, and alternative I for next-version item 4 |
| ADR-0033 payout and payment addresses | The two money addresses the contract pays |
| ADR-0034 chain and mainnet gate | The chain order and the 39 conditions before mainnet |
| ADR-0039 amend a funded deal | The settlement note of next-version item 2 |
| ADR-0040 standing offers | The seller contract of next-version item 7 |

The entries D57, D77 to D82 and D85 are in holdback `docs/decisions-today.md`, which is not copied here because most of it covers other layers.

## 8. Maintenance note

- **Visibility:** public. Branch rules, secret scanning and vulnerability reporting are GitHub settings, not files here; CI is the check this repository carries.
- **Reporting a vulnerability:** see [`SECURITY.md`](SECURITY.md).
- **CI** (`.github/workflows/ci.yml`, actions pinned to commits as holdback pins them) runs on every push to `main`, every `phase-one-*` tag and every pull request. It has three jobs:
  - `fidelity` fails if `contracts/src` differs from holdback's `d621291e`;
  - `contracts` builds and runs the Foundry suites;
  - `gitleaks` scans for secrets, with three named false positives allowed in `.gitleaks.toml`.
- **No secrets:** no key, no `.env` file and no RPC endpoint. `foundry.toml` pins chain ID 31337 and configures no RPC.
- **Updates come from holdback.** A new contract version becomes a new snapshot commit and tag here. The contract code is never edited here.

## 9. Licence

Apache License 2.0 ([`LICENSE`](LICENSE)), as in holdback. Third-party code stays in its own repositories, linked as submodules under their own licences.
