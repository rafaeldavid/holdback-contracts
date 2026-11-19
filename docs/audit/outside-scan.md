# Zero Cool's scan of Crow's contracts and its review of the fixes

**State, 2026-11-19: Zero Cool, a security firm, ran two automated reviews of Crow's five contract files. The first was a deep scan on 2026-11-18 of the deployed version, at commit `27ab44e8` (tag `contracts-phase-one-1`). It reported 69 findings: 9 Medium, 9 Low and 51 Informational, none Critical or High. 65 of them were already in Crow's own records. Crow then made six changes in a new contract version, at commit `d621291e` on the branch `contracts-audit-ready`. The second review, on 2026-11-19, checked those six changes. It found that five close their findings, that the sixth (the beacon probe) closes its finding only in part, and that no change adds a problem beyond one new Informational finding. Three items stay open, each Informational. The new version is not deployed: the contracts live on Sepolia are the first version, and they cannot be changed. Neither review is a line-by-line audit by human reviewers, and nothing on this page says the contracts are secure.** Measured from the data files beside this page unless a sentence says otherwise.

Crow bought both reviews through deals on Crow, as case studies of its own escrow, with test tokens on Sepolia [measured on both operators and on Sepolia]:
- The first scan was delivered in deal `0xb00e30e451dde2e3729e29085099f27ffa80e3a07a8b346759db277b9ae256ce`, Released on 2026-11-18 at 16:24:00 UTC.
- The fix review was delivered in deal `0x5533006ae164c48e5d4894f7313abe77a125b3fcb0268f0e0478fa24f2bd913a`, Released on 2026-11-19 at 10:58:12 UTC.

A first deal for the scan, `0x4e11ea5f…5ee6`, was settled by agreement, with the price returned, after the delivered report failed two of that deal's checks.

## What was reviewed, and how

| | The first scan | The fix review |
| --- | --- | --- |
| Process | Zero Cool's automated scan, deep mode (job type `scan`) | Zero Cool's automated fix review, deep mode (job type `fix_review`), with the first scan as its parent |
| Code | The five files of `contracts/src/` at `27ab44e8bf359783116a95eb45102c95ce5c3ed6`: 1,747 source lines as the firm counts them | The same five files at `d621291eb4f57d7c4b3cdae71bf7c6310b822a9e`, read against base `27ab44e8`: 1,800 source lines |
| Rated against | A planned Ethereum mainnet deployment with native USDC (the scan's "audit focus" artifact), not Sepolia's test tokens | The same |
| Not read | The operator API, the adjudicator service, the judgment pipeline, the site; Coinbase's Commerce Payments escrow, Solady and OpenZeppelin, except where the five files call them | The same |
| Finished | 2026-11-18 13:39:27 UTC, after a run of 8,515 s | 2026-11-19 10:56:32 UTC, after a run of 5,613 s |
| Findings | 69: 9 Medium, 9 Low, 51 Informational. Disposition: 65 known, 3 valid, 1 duplicate | 70: the 69, with no rating changed, plus 1 new Informational finding. Disposition: 65 known, 4 valid, 1 duplicate |
| Data | [`outside-scan/first-scan.json`](outside-scan/first-scan.json): the job and its 76 artifacts | [`outside-scan/fix-review.json`](outside-scan/fix-review.json): the job and its 81 artifacts, including Crow's request (`guidance`) and three comments |

"Known" is the scan's word for an issue that Crow's own records already listed: [`known-issues.md`](known-issues.md), the threat model and Crow's earlier reviews. For a known finding the scan took Crow's rating, and gave Informational where Crow gave none. So a known finding's rating says how Crow rated it, not how the scan would rate it.

## The six changes, and the fix review's verdict

`git diff contracts-phase-one-1 d621291e -- contracts/src` shows all six: 4 files changed, 76 lines added and 23 removed, comments included.

| Change | Findings | Verdict |
| --- | --- | --- |
| (a) The rules contract asks the beacon for a round when it is deployed, and refuses an address that does not answer (`BadBeacon`) | `4989a790` | **Closed in part.** The probe refuses an address with no code, a beacon that reverts and a short answer. It still accepts the precompiles 0x02 to 0x04, a word that is not a valid `uint64` round, the largest `uint64`, and a beacon that answers only at deployment. That residual is the new finding `bf7f2cb1` |
| (b) The beacon's pairing gas is set at deployment, with a floor of 102,900 gas (`PairingGasBelowFloor`) | `3a373655`, `f90d53c1`, `b1a37663` | Closed. A repricing above the deployed value still needs a new beacon |
| (c) A call that ran short of gas reverts `NotEnoughGas`, not `InvalidSignature` | `2e8e2fd3`, `0ac9ec26` | Closed. A valid proof never reads `InvalidSignature` at any gas limit |
| (d) Funding refuses terms whose three dispute fields are not zero | `008bef5f`, `a1c9b4f1` | Closed |
| (e) A primary's decision must carry empty beacon fields, and an escalation decision no appeal ground | `67531304`, `f6acda91` | Closed |
| (f) The comment on the escrow expiry's 48-bit bound is corrected | `cdf06aaa` | Fixed: the bound matches the code |

The fix review also answered two more of Crow's questions:
- **Does any change add a problem?** No, beyond the probe's residual. A bad proof reads `NotEnoughGas` only in a band of 92 gas values at the gas edge, and a bad proof never lands. Each new refusal comes before any write.
- **Is the probe sound when the beacon is deployed in the same batch?** Yes, when the beacon is deployed first, as `contracts/script/deploy-sepolia.sh` does. In the wrong order the probe fails closed.

## Every finding

Columns:
- **Scan** and **Disposition** are the firm's.
- **Crow** is Crow's own rating, and **Triage** is Crow's reading of the finding against the code at the tag: confirmed (a new defect), known, or not a defect.
- **Status** is what Crow did.
- **Fix review** is the verdict on the change that answers the finding; "no change" means that no change answers it.

The ID is the first 8 characters of the finding's artifact ID in the data files.

<!-- findings table: rendered by node docs/audit/outside-scan/table.mjs --write -->

70 findings: 69 from the first scan and 1 new in the fix review. By Crow's status: open 3, fixed in part 1, fixed in the new version 10, fixed off chain 4, deploy check 2, accepted limit 47, not a defect 3. Every row is in `triage.json` (70 rows).

| ID | The finding (the scan's title) | Scan | Disposition | Crow | Triage | Status | Fix review | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `696fcaca` | Carried-delivery decide() can revert after publishing the primary's seed and verdict, letting the seller replace the delivery | Info | valid | Info | confirmed | open | open | known-issues.md OS-1. Crow's operators post every delivery on its own and carry one only in an accept (T-526); the contract path is unchanged, so a direct relayer can still carry one. |
| `8a875efc` | A colluding run of four or more proposer slots gives several known appeal-panel draws, more than TA-2's one | Info | valid | Info | confirmed | open | open | known-issues.md OS-4. The docs now state n - 2 known draws for a run of n slots; the design change waits for the mainnet gate. |
| `bf7f2cb1` | Constructor beacon probe accepts codeless precompiles 0x02-0x04 and non-round words, contradicting BadBeacon NatSpec | Info | valid | Info | confirmed | open | new | New in the fix review: the residual of change (a). Only a deployer's mistake reaches it, and deploy-sepolia.sh rules it out by the beacon's code hash. |
| `4989a790` | A wrong BEACON constructor argument blocks triggerFallback and leaves Delivered deals without a timeout exit | Info | known | Info | known | fixed in part | closed in part | Change (a): the constructor asks the beacon for a round and refuses with BadBeacon. The residual is bf7f2cb1. |
| `008bef5f` | Terms with dispute fields that are not zero fund | Low | known | Low | known | fixed in the new version | closed | Change (d): funding refuses terms whose three dispute fields are not zero. |
| `3a373655` | Beacon pairing gas cap is a fixed constant with no setter | Low | known | Low | known | fixed in the new version | closed | Change (b): the pairing gas is set at deploy, with a floor of 102,900 gas. |
| `a1c9b4f1` | The contract takes terms whose dispute fields are not zero | Low | known | Low | known | fixed in the new version | closed | Change (d). |
| `f90d53c1` | Fixed 250,000 gas cap on PAIRING_CHECK can refuse every real round after a repricing | Low | known | Low | known | fixed in the new version | closed | Change (b). |
| `0ac9ec26` | A valid proof sent with too little gas reverts as InvalidSignature | Info | known | Info | known | fixed in the new version | closed | Change (c): a call that ran short of gas reverts NotEnoughGas, not InvalidSignature. |
| `2e8e2fd3` | A valid beacon proof sent with too little gas reverts as InvalidSignature | Info | known | Info | known | fixed in the new version | closed | Change (c). |
| `67531304` | An escalation's appeal ground and a primary's beacon fields are signed and not checked | Info | known | Info | known | fixed in the new version | closed | Change (e): a primary's decision must carry empty beacon fields, and an escalation decision no appeal ground. |
| `b1a37663` | PAIRING_GAS is fixed forever | Info | known | Info | known | fixed in the new version | closed | Change (b). |
| `cdf06aaa` | agreeAndFund comment says the escrow expiry fits 48 bits whenever EXPIRY_MARGIN does; it does not | Info | valid | Info | confirmed | fixed in the new version | fixed | Change (f): the comment on the escrow expiry's 48-bit bound is corrected. |
| `f6acda91` | Two register verdicts to enforce empty fields are not in the code | Info | known | Info | known | fixed in the new version | closed | Change (e). |
| `e30c079b` | A failed balance read after a relay mined defers that deal's timeouts | Medium | known | Medium | known | fixed off chain | no change | Operator code, fixed on main before the scan (T-409, PR 512). |
| `542b89b8` | A reorg that drops a lane's last transaction leaves its nonce too high | Low | known | Low | known | fixed off chain | no change | Operator code, fixed on main before the scan (T-409, PR 512). |
| `83985e09` | A restart after the panel returned reruns the panel | Low | known | Low | known | fixed off chain | no change | Adjudicator service code: it now keeps its judged result before it signs, so a restart calls no judge again (T-530, PR 652, deployed 2026-11-18). |
| `c65cd6d5` | 13 ways bypass the lint rule that makes each chain read name a block | Low | known | Low | known | fixed off chain | no change | Operator code, fixed on main before the scan (T-409, PR 512). |
| `1661b40c` | Constructor accepts a Commerce Payments v1.0.0 escrow, so funded holds can never pay the seller | Info | known | Info | known | deploy check | no change | Needs a deployer's mistake. deploy-sepolia.sh --check compares the deployed code with the record. |
| `30145111` | Constructor accepts any nonzero BEACON_MARGIN, so a wrong value breaks panel-seed secrecy or disables fallback and appeal | Info | known | Info | known | deploy check | no change | A contract cannot know its chain's slot time; the deploy script sets the margin for the chain. |
| `15b54cd1` | A call that carries the buyer's key publishes it even when the call reverts | Medium | known | Medium | known | accepted limit | no change | Same cause as a0cd835b. |
| `2dd4fb70` | Escalation panel round can still be learned by a three-slot proposer | Medium | known | Low | known | accepted limit | no change | Needs three colluding proposer slots. A mainnet gate item measures it. |
| `3db0ab8b` | Fallback round can still be learned by a three-slot proposer colluding with a party | Medium | known | Low | known | accepted limit | no change | As 2dd4fb70. |
| `3ed7c89a` | A call that carries the buyer's key envelope publishes it even when the call reverts | Medium | known | Medium | known | accepted limit | no change | Its High part, the key on a refunded deal, was fixed before the scan (PR 125); the limit is as a0cd835b. |
| `7a191c3c` | A call that carries the buyer's key publishes it even when the call reverts or loses a race | Medium | known | Medium | known | accepted limit | no change | Same cause as a0cd835b. |
| `90744dd1` | The primary adjudicator chooses its own panel seed | Medium | known | Medium | known | accepted limit | no change | known-issues.md DS-1. Bounded by the parties' own choice of primary adjudicator. |
| `a0cd835b` | Key-bearing call publishes the buyer's envelope even when it reverts | Medium | known | Medium | known | accepted limit | no change | known-issues.md, H-2 limit. Closing it on chain needs a commit and reveal of the key, a new protocol step (D26). |
| `e7131dba` | The primary adjudicator chooses its own panel seed through its seed commitment | Medium | known | Medium | known | accepted limit | no change | As 90744dd1. |
| `1aea5848` | Residual two-way seed choice by the primary after the seed tag fix | Low | known | Low | known | accepted limit | no change | Fixed before the scan; the residual adds nothing to DS-1. |
| `93457d96` | Signature subgroup membership is checked only by the PAIRING_CHECK precompile | Low | known | Low | known | accepted limit | no change | EIP-2537 makes the precompile check the subgroup. A mainnet gate item runs the test vectors on every client. |
| `051d0f3e` | A payout address that is a deployment contract strands the seller's payment | Info | known | Info | known | accepted limit | no change | Both parties sign the payout addresses. |
| `069b8a2b` | roundAt returns round 0 before genesis while drand says round 1 | Info | known | Info | known | accepted limit | no change | No deal can name a time before the beacon's genesis. |
| `0b642051` | decide verifies the beacon proof before the adjudicator's signature | Info | known | Info | known | accepted limit | no change | The cost is the sender's own gas. |
| `0f01bd19` | After an escalation's decision t1 stays the escalation's time and a bad beacon proof reverts with the beacon's own error | Info | known | Info | known | accepted limit | no change | By design. |
| `25127f2a` | The settlement for late work releases a key with no posted delivery | Info | known | Info | known | accepted limit | no change | By design: both parties sign the late-work settlement. |
| `2adb1339` | Escrow keeps a refundable amount after capture that HoldbackRules never uses | Info | known | Info | known | accepted limit | no change | Escrow behaviour; nothing can use the amount. |
| `30c0020e` | A plain key that takes delegated code (EIP-7702) loses its pending signatures | Info | known | Info | known | accepted limit | no change | The deal goes to the fallback or the default its terms name. The bound the docs stated was too narrow (see da30d5b8) and is corrected. |
| `348991e3` | Beacon relies on clients' EIP-2537 subgroup check for a unique seed | Info | known | Info | known | accepted limit | no change | As 93457d96. |
| `3dec9493` | MutualSettlement digest binds no signer or role, so one shared-key contract-wallet signature fills both slots | Info | known | Info | confirmed | accepted limit | no change | known-issues.md OS-3. Needs two contract wallets that accept one shared key. The signed settlement gains the signer's address in the rebuilt contracts. |
| `44e8731f` | Direct steps leave the operators' view behind the chain | Info | known | Info | known | accepted limit | no change | Deferred to T-227, before mainnet. |
| `49c807c3` | A co-signed mutual payout to a deployment contract strands the tokens | Info | known | Info | known | accepted limit | no change | As 051d0f3e. |
| `5a998b98` | An escalation window shorter than the chain's floor cannot be decided | Info | known | Info | known | accepted limit | no change | The parties choose the window (D31). |
| `5c7d4a2f` | An accept whose key does not decrypt the work has no remedy on chain | Info | known | Medium | known | accepted limit | no change | Phase one has no appeals and no bonds (D57, ADR-0031). Bounded by one deal's price and fee. |
| `5e3efbe5` | No fallback without an on-chain deliver, so a silent primary ends in reclaim | Info | known | Info | known | accepted limit | no change | The seller protects itself by posting its delivery (D32). |
| `6d458080` | A stablecoin issuer freeze makes a push transfer revert | Info | known | Info | known | accepted limit | no change | A token issuer's control over its own token; out of scope. |
| `6fd22a03` | roundAt returns 0 before genesis where drand returns 1 | Info | known | Info | known | accepted limit | no change | As 069b8a2b. |
| `714ab9c7` | The funding's safety against a front-run rests on the token's payee rule | Info | known | Info | known | accepted limit | no change | A trust assumption on the token. |
| `72ae5dbd` | Undeployed smart-wallet buyer cannot fund | Info | known | Info | known | accepted limit | no change | A wallet deploys before it funds; the agent docs say so. |
| `768cd52b` | A plain key that takes delegated code loses its pending signatures | Info | known | Info | known | accepted limit | no change | Duplicate of 30c0020e. |
| `7d33e4ab` | roundAt casts the round to uint64 and wraps for times no deal can hold | Info | known | Info | known | accepted limit | no change | Unreachable through HoldbackRules. |
| `8369430c` | Buyer's direct escrow reclaim leaves the rules contract state stale | Info | known | Info | known | accepted limit | no change | By design (TA-1). |
| `93eba475` | An adjudicator can collude with one party | Info | known | Info | known | accepted limit | no change | The parties choose the adjudicators; bonds and appeals return later. |
| `9570b0ce` | A party must trust all three adjudicators it names | Info | known | Medium | known | accepted limit | no change | As 5c7d4a2f. |
| `a4660656` | With two envelopes addressed to the buyer, the relayer chooses which is released | Info | known | Info | known | accepted limit | no change | As aeb9c2ff. |
| `ad2ddc6d` | The contracts are not verified on Etherscan | Info | known | Info | known | accepted limit | no change | All five contracts are exact matches on Sourcify. |
| `aeb9c2ff` | With two envelopes addressed to the buyer, the relayer chooses which the contract releases | Info | known | Info | known | accepted limit | no change | The contract sees only hashes; the buyer's own check refuses such a delivery. |
| `aef7f785` | Funds stay held if every operator, adjudicator and agent vanishes | Info | known | Info | known | accepted limit | no change | Anyone may trigger a timeout; one live party is enough. |
| `b6806df8` | An EIP-7702 delegated account can sign only if its delegate implements ERC-1271 | Info | known | Info | known | accepted limit | no change | The wallet's delegate decides. |
| `babd6d40` | EXPIRY_MARGIN has no lower bound | Info | known | Info | known | accepted limit | no change | No lower bound is needed; the deploy script sets the value for the chain. |
| `c1a83183` | ERC-6492 prepare call can move a deal's stage inside its funding transaction | Info | known | Info | known | accepted limit | no change | The prepare call cannot reach money. |
| `c39d470a` | No decision when no beacon round can be proven in a window | Info | known | Info | known | accepted limit | no change | The case goes to the fallback or the default. |
| `cdae1d18` | A refused proof with a point outside G1 burns about 283,000 gas for its sender | Info | known | Info | known | accepted limit | no change | The cost is the sender's own gas. |
| `d29097f1` | decide checks the beacon proof before the adjudicator's signature | Info | known | Info | known | accepted limit | no change | As 0b642051. |
| `d2ee602a` | ERC-8183 event names are not checked against the canonical text | Info | known | Info | known | accepted limit | no change | ERC-8183 is a draft. |
| `da30d5b8` | Contract seller's changing ERC-1271 answer makes the primary's carried-delivery decide() revert | Info | duplicate of `696fcaca` | Info | confirmed | accepted limit | no change | known-issues.md OS-2. The scan marks it a duplicate of 696fcaca. The docs' bound for contract signers is corrected. |
| `e33be4dc` | A wrong first decision has no remedy on chain | Info | known | Medium | known | accepted limit | no change | As 5c7d4a2f. A per-deal cap is a mainnet gate item (ADR-0034). |
| `e42f2687` | The funding's safety against a front-run rests on the token keeping ERC-3009's payee rule | Info | known | Info | known | accepted limit | no change | As 714ab9c7. |
| `0987054c` | mutualSettle can release the key with no payment to the seller | Info | known | Info | not a defect | not a defect | no change |  |
| `36ee77e9` | Beacon decompression can emit y equal to p when the root is 0 and the sign flag is set | Info | known | Info | not a defect | not a defect | no change | Unreachable. |
| `a870d5ef` | Seller's Terms signature is over a raw typed-data digest, not a named type | Info | known | Info | not a defect | not a defect | no change |  |

<!-- end of findings table -->

## What stays open, and why

1. **`696fcaca`, a carried delivery's reject.** A seller can make the primary's decision revert when that decision carries the seller's delivery. The revert comes after the decision's calldata has made the panel seed and the verdict public, and the seller can then deliver again. The contract path is unchanged at `d621291e`. Crow's operators post every delivery on its own and carry one in a decision only for an accept (T-526, on `main` and live since 2026-11-18). Anyone who relays directly can still send the carried form. The harm stays within one deal's judging. The fix review also finds that the threat model's sentence on a contract signer (TA-7) is still not right for this path. Crow will choose between making sure no supported sender carries a delivery except in an accept, and accepting the contract's behaviour as a known limit. Either way, TA-7 is corrected to match.
2. **`8a875efc`, appeal draws from a run of proposer slots.** A colluding run of n proposer slots gets n − 2 known draws of the appeal panel. The docs on `main` now state n − 2 ([`known-issues.md`](known-issues.md), OS-4). The design change, fixing the escalation round by state instead of by block, waits for the mainnet gate. Phase one has no party appeals, so the harm is bounded as the BR-6 residual.
3. **`bf7f2cb1`, the beacon probe's residual (new).** With a beacon address that passes the probe but cannot serve rounds, `triggerFallback` reverts. A Delivered deal whose primary stays silent then has no exit through the rules contract, and the payer gets the hold back through the escrow's own `reclaim` after the escrow's expiry, which falls 86,400 s after the deal's last decision deadline. Only a deployer's mistake reaches it, and `deploy-sepolia.sh --check` rules that mistake out by comparing the beacon's code hash. The fix review suggests a complete fix (a `triggerFallback` that does not need the beacon) and a partial one (check the code length, decode the round as a `uint64` and refuse the largest value). Either one changes reviewed code and would need its own review.

The fix review also lists text that does not match the code, and deviations it does not rate (the audit outlook in `fix-review.json`, `open_questions`):
- the `_call` NatSpec and `DrandQuicknetBeacon.sol` lines 67 to 68 describe failures that do not happen;
- `IHoldbackBeacon` declares neither `NotEnoughGas` nor `PAIRING_GAS`;
- `earlyAccept` is refused after `triggerFallback` or an escalation, while ADR-0031 says "at any time before a decision". The cost is at most one deal's adjudicator fee.

## How to check this page

- **The commits.** `git rev-parse 'contracts-phase-one-1^{commit}'` prints `27ab44e8bf359783116a95eb45102c95ce5c3ed6`, the commit the deployment record names ([`scope.md`](scope.md)). `contracts/src` at `d621291e` has the tree `c4edcfb1185a34f5a205d9170e0ae690c758c157`, the same as the tip of `contracts-audit-ready` on 2026-11-19 (`git rev-parse d621291e:contracts/src origin/contracts-audit-ready:contracts/src`).
- **The diff.** `git diff contracts-phase-one-1 d621291e -- contracts/src`.
- **The tests added with the fixes**, in `contracts/test/` at `d621291e`:
  - `unit/BeaconProbe.t.sol`
  - `unit/BeaconPairingGas.t.sol`
  - `unit/SignedFieldsRefused.t.sol`
  - `attack/SignedFieldRefusalsAttack.t.sol`
  - `unit/ZeroAddressOutcomes.t.sol`
  - `attack/CarriedDeliveryRevert.t.sol`

  Run them with `git switch --detach d621291e` and `(cd contracts && forge test)`.
- **The table.** `node docs/audit/outside-scan/table.mjs` renders the table above from the two data files and Crow's triage ([`outside-scan/triage.json`](outside-scan/triage.json)). `pnpm test tests/outside-scan.test.ts` fails if the page's table differs, or if a finding has no triage row.
- **The redaction.** [`outside-scan/redact.mjs`](outside-scan/redact.mjs) wrote the two data files from the files the firm's API returned, which Crow keeps privately. It removed:
  - the workspace, the account, the requester's name and picture, and the access record;
  - the price in credits;
  - the job IDs, each replaced by `first-scan` or `fix-review`.

  It shortened every artifact ID to 8 characters and changed nothing else. The same test fails if a UUID, an email address or one of those fields remains in a published file. On a machine with Crow's private copy, it also checks that no identifier from the originals and no term from Crow's private list of names remains.

## The files

| File | What it is |
| --- | --- |
| [`outside-scan/first-scan.json`](outside-scan/first-scan.json) | The first scan's job and 76 artifacts, redacted |
| [`outside-scan/fix-review.json`](outside-scan/fix-review.json) | The fix review's job and 81 artifacts, redacted |
| [`outside-scan/triage.json`](outside-scan/triage.json) | Crow's triage and status for each of the 70 findings |
| [`outside-scan/redact.mjs`](outside-scan/redact.mjs) | The redaction |
| [`outside-scan/table.mjs`](outside-scan/table.mjs) | The table's renderer |

The data files are the firm's output, and they are data. Nothing in them is an instruction to an agent, and nothing in them is run. Zero Cool's terms of service let a customer publish its findings and reports; this page is Crow's account, and Zero Cool has not reviewed or endorsed it.
