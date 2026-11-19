# Functions: the basics by name

For each external and public function of the phase-one contracts: who may call it, what it checks of its inputs, what it emits, what state it touches and what it calls. Then the access-control, reentrancy, replay and integer-bound reading, the code left from removed features, the no-admin rule, and the triage of every static-analysis result. Line numbers are at the tag `contracts-phase-one-1`.

This page is a dated record: the audit-readiness review (T-499) read the code on 2026-11-17 with Slither 0.11.6 and Aderyn 0.6.8. Labels: **measured** (read in the file or produced by the command), **inferred** (concluded from reading). What it found that a next version could fix is in [`known-issues.md`](known-issues.md), section 10.

## The fixed build

On the lane `contracts-audit-ready` the contracts carry an outside scan's fixes (T-527, T-528 and T-529). The tables below stay the record of the tag; on the fixed build these rows differ [measured: `git diff contracts-phase-one-1 contracts-audit-ready -- contracts/src`]:

- **`HoldbackRules` constructor:** it also refuses a beacon that does not answer `roundAt` (no code, or the call reverts or returns no round) with `BadBeacon` (T-527).
- **`agreeAndFund`:** it also refuses terms whose `disputeBy`, `disputeJudgeSec` or `disputeFallbackSec` is not 0 (`InvalidMessage`; T-529).
- **`decide`:** it also refuses a primary's decision with any beacon field set (`beaconSourceHash` not `keccak256("")`, a round, a value or a signature), and the appeal adjudicator's decision on an escalation with an appeal ground (`InvalidMessage`; T-529).
- **`DrandQuicknetBeacon` constructor:** it takes `pairingGas`, the gas forwarded to the pairing precompile, and refuses a value below `MIN_PAIRING_GAS` = 102,900 with `PairingGasBelowFloor`. It sets two immutables, `PAIRING_GAS` and `P_LO` (T-528). The deploy script passes 250,000, reads it back and records it (`contracts.DrandQuicknetBeacon.args`).
- **`beaconValue`:** the pairing gets `PAIRING_GAS`, read with the public getters `PAIRING_GAS()` and `MIN_PAIRING_GAS()`. A call that runs short of gas before the proof is judged reverts with `NotEnoughGas`, not `InvalidSignature` (T-528).

Line numbers on the lane differ from the tag's.

## Every external and public function

Authority never comes from `msg.sender`: every row is "anyone", and the signature column says whose EIP-712 signature (domain "Holdback", "0.8", chain ID, this contract) the call needs. `t` is the settlement view; the commitment ID `id = H.commitmentId(t)` is recomputed in every call, so altered terms name another deal. All signature checks use Solady `SignatureCheckerLib.isValidSignatureNowCalldata` (`HoldbackRules.sol:567-571`): ECDSA for an address without code, ERC-1271 for one with code, and always false for `address(0)` (`solady/src/utils/SignatureCheckerLib.sol:85`) [measured].

**HoldbackRules**

| Function | Who may call (authorization) | Input checks | Emits | State touched; external calls | Notes |
| --- | --- | --- | --- | --- | --- |
| `constructor` (`:82-101`) | the deployer, once | escrow, collector, beacon, token not zero (`ZeroAddress`); beacon margin not 0 off chain ID 31337 (`NoBeaconMargin`) | none | sets six immutables (`ESCROW`, `ERC3009_COLLECTOR`, `EXPIRY_MARGIN`, `BEACON`, `TOKEN`, `BEACON_MARGIN`); Solady EIP712 caches the domain | No code-size check on the addresses; any `expiryMargin` (a huge one makes every deal `Unrepresentable`, a deploy-time error) |
| `agreeAndFund` (`:146-192`) | anyone; needs the seller's signature over `id`, the primary adjudicator's `AdjudicatorAcceptance`, the buyer's `Agree`, and the payment address's ERC-3009 authorization (checked by the token through CPP) | stage None (`WrongStage`); `now < offerExpiresAt` and `now < fundBy` (`DeadlinePassed`); `now <` both messages' `expiresAt` (`MessageExpired`); `bondReserved == 0`, `t.token == TOKEN`; five deadlines strictly increasing; `maxSubmissions == 1`; `appealDecideSec >= 1`; `appealWindowSec == 0` (`InvalidMessage`); `fallbackBy <= LAST_TIMESTAMP`, `appealDecideSec <= 2^32-1`, `price + fee <= 2^120-1`, expiry `<= 2^48-1` (`Unrepresentable`); price + fee overflow panics; CPP refuses price + fee = 0 (`ZeroAmount`) | `JobCreated`, `JobFunded`, `SettlementAddresses` | writes `_deals[id]` (stage Held, `seedTag`) **before** `ESCROW.authorize` (`:186-191`); CPP calls the collector, which calls the token's `receiveWithAuthorization` | No zero check on `buyer`, `seller`, the two money addresses or the three adjudicators. A zero buyer, seller or primary cannot sign, so the deal cannot fund; a zero fallback or appeal adjudicator can never decide, so that path defaults to a refund; a zero payout address is the parties' own signed choice (D32) [inferred] |
| `deliver` (`:198-204`) | anyone; needs the seller's `Delivery` signature | stage Held; `now < deliverBy` (`DeadlinePassed`); `attempt == 1` (`InvalidMessage`); seller signature | `JobSubmitted` | writes `deliveryHashOf[id]`, then stage Delivered, attempt 1; no external call | Optional on the happy path |
| `decide` (`:212-255`) | anyone; needs the signature of the adjudicator whose turn it is (primary in Delivered, fallback in FallbackJudging, appeal adjudicator in Escalated); in Held also the seller's `Delivery` | `now < m.expiresAt`; in Held, the `deliver` checks; stage has a turn (`WrongStage`); `m.role` is the turn's role, `m.attempt` and `m.deliveryHash` are the posted ones, outcome valid for the role (appeal cannot escalate), key only with accept (`InvalidMessage`); `now <` role deadline (`DeadlinePassed`); primary: `seedTag(keccak(seed), id) == d.seedTag`; fallback / appeal: `beaconRound` is the state's round, `beaconValue` proven by `BEACON`, seed = `panelSeed` (`BadSeed`); adjudicator signature; first instance: `appealGroundHash == keccak("")`; accept: key present (`InvalidMessage`) | `JobSubmitted` (Held), `Decided`; accept: `JobCompleted`, `PaymentReleased`, `KeyReleased`; reject: `JobRejected`, `Refunded`; `FeePaid` when fee > 0 | reads `_deals[id]` once into memory, writes it once in `_firstInstance` or `_escalationDecision` **before** `capture` / `void`; staticcalls `BEACON.beaconValue` and ERC-1271 signers before the write | Escalation moves no money and sets `t1`. The key on an accept is not checked against the delivery's envelope list (threat T19, accepted) |
| `earlyAccept` (`:327-354`) | anyone; needs the buyer's `EarlyAccept`; in Held also the seller's `Delivery` | stage Held or Delivered; `now < m.expiresAt`; buyer signature; in Held the `deliver` checks; `m.attempt == dv.attempt`, `m.deliveryHash == dh == deliveryHashOf[id]` (`InvalidMessage`); key proof: index in range, envelope addressed to the buyer, list hashes to `dv.encryptedKeysHash` (`BadKeyProof`) | `JobSubmitted` (Held), `JobCompleted` (evaluator = buyer), `PaymentReleased`, `Refunded` (fee > 0), `KeyReleased` | storage stage Released, reason AcceptedEarly **before** `capture(price, fee 0)` and `void` (fee) | No deadline of its own; CPP refuses a capture from the escrow's expiry |
| `mutualSettle` (`:360-388`) | anyone; needs the buyer's and the seller's `MutualSettlement` signatures over one struct hash | stage Held, Delivered, FallbackJudging or Escalated; `now < m.expiresAt`; without a delivery: no key, zero hash, stage Held; after a delivery: hash is the posted one (`InvalidMessage`); both signatures; with `releaseKey`: `deliveryHash(id, dv) == m.deliveryHash` and the key proof (`BadKeyProof`); in `_payOut`: each payout nonzero and to one of the two money addresses, sum == price (`InvalidMessage`; sum overflow panics) | `PaymentReleased` (seller share > 0), `Refunded` (rest > 0), `MutuallySettled`, `KeyReleased` (with `releaseKey`) | storage stage Settled **before** at most one `capture` and one `void` | In Held with `hasDelivery` the hash is not checked against storage: the late-work settlement, by design (SC-5b) |
| `reclaim` (`:424-431`) | anyone | stage Held; `now >= deliverBy` (`TooEarly`) | `Refunded` (unless the hold was already reclaimed on CPP), `JobExpired` | storage stage Refunded, reason Reclaimed, **then** `paymentState` (view, after expiry only) and `void` | |
| `triggerFallback` (`:434-442`) | anyone | stage Delivered; `now >= judgeBy` (`TooEarly`) | `FallbackTriggered(round)` | stage FallbackJudging, `t1`; staticcall `BEACON.roundAt` | May be called after `fallbackBy`; then the fallback has no window and `triggerDefault` applies at once |
| `triggerDefault` (`:446-459`) | anyone | stage FallbackJudging and `now >= fallbackBy`, or Escalated and `now >= t1 + appealDecideSec` (`TooEarly`); else `WrongStage` | `Defaulted`, then `Refunded` (unless reclaimed on CPP) | storage stage Refunded, reason Defaulted, **then** `void` | |
| `dealOf(bytes32)` (`:106`) | anyone (view) | none | none | reads `_deals` | |
| `typedDataHash(bytes32)` (`:111`) | anyone (view) | none | none | none | The digest a party signs |
| `deliveryHashOf(bytes32)` (`:69`, public mapping) | anyone (view) | none | none | reads | |
| `KEY_DECISION`, `KEY_EARLY_ACCEPT`, `KEY_MUTUAL`, `MUTUAL_FEE_SHARE_BPS` (constants, `:28-37`) | anyone (pure getters) | none | none | none | `MUTUAL_FEE_SHARE_BPS` is read by no code (Dead and left-over code, below) |
| `ESCROW`, `ERC3009_COLLECTOR`, `EXPIRY_MARGIN`, `BEACON`, `TOKEN`, `BEACON_MARGIN` (immutables, `:50-62`) | anyone (getters) | none | none | none | |
| `eip712Domain()` (Solady, ERC-5267) | anyone (view) | none | none | none | |

**DrandQuicknetBeacon**

| Function | Who may call | Input checks | Emits | State; external calls | Notes |
| --- | --- | --- | --- | --- | --- |
| `constructor` (`:71-73`) | deployer | none | none | sets immutable `P_LO` | No parameters: key, genesis, period are constants |
| `roundAt(uint256)` (`:76`, public pure) | anyone | none; returns 0 before genesis | none | none | `uint64` cast cannot truncate for any `t` the rules contract passes: at most about 2^64 + 2^38 s, giving a round near 6.1·10^18 < 2^64 [inferred] |
| `beaconValue(uint64, bytes)` (`:83-91`, external view) | anyone | length 48; compressed flag set, infinity flag clear; `x < p`; `x^3 + 4` is a square; sign bit picks `y`; one pairing check with capped gas `PAIRING_GAS` = 250,000, a constant at the tag and a constructor argument on the fixed build (above); every precompile output length checked (`InvalidSignature`) | none | staticcalls to 0x02, 0x05, 0x0b, 0x0f, 0x10 only | The encoding is unique (flags fixed, `x < p`, sign bit fixed by `y`), so `sha256(signature)` is unique per round [inferred]. Subgroup membership is left to the pairing precompile, which fails for a point outside G1 |
| `hashToG1(bytes32)` (`:98-103`, public view) | anyone | none | none | staticcalls 0x02, 0x05, 0x10, 0x0b | |
| `GENESIS`, `PERIOD` (constants) | anyone | none | none | none | |

## Authorization and access control

Every state-changing function is open to any caller, and each one's authority is the signature set in 5.1 or a deadline that has passed [measured: no read of `msg.sender` or `tx.origin` in `src/` (grep finds none)]. No function has a role, an allowlist or a modifier. The contract's only privileged power is as CPP's operator for its own payments (`operator: address(this)`, `:127`), and each `capture` and `void` is reached only through the checks above [inferred].

## Reentrancy ordering around the escrow calls

Every path writes the deal's word before the first state-changing external call [measured by reading]:

| Path | Storage write | External calls after it |
| --- | --- | --- |
| `agreeAndFund` | `:186-187` | `ESCROW.authorize` `:191` |
| `decide` → `_firstInstance` / `_escalationDecision` | `:286` / `:292` / `:300` | `capture`, `void` in `_settleDecision` |
| `earlyAccept` | `:341`, `:346` | `capture` `:348`, `void` `:349` |
| `mutualSettle` | `:384` | `_payOut`: `capture` `:406`, `void` `:413` |
| `reclaim`, `triggerDefault` → `_refundAll` | `:508` | `paymentState` (view) `:513`, `void` `:516` |

The only calls before a write are staticcalls (`BEACON.beaconValue`, `BEACON.roundAt`, ERC-1271 `isValidSignature`), which cannot change state. CPP's `capture`, `void`, `authorize` are `nonReentrant`. A re-entry from the token (only if a deployment chose a hook token, which scope forbids) finds the deal closed and reverts `WrongStage` [inferred].

## Signature replay

- **Domain.** Solady EIP712, name "Holdback", version "0.8", `chainid()` and `address()` (`solady/src/utils/EIP712.sol:52-60`); the separator is rebuilt when the chain ID differs from the cached one, so a fork cannot replay [measured by reading]. Two deployments, or the same terms on two chains, have different domains.
- **Per message.** Each struct hash binds the commitment ID; the decision also binds the adjudicator, role, attempt, delivery hash and expiry; the acceptance binds the primary and its seed commitment; the mutual settlement binds the payouts and the token. Nonces are "signed only": the contract needs no nonce registry because every message applies at most once per deal: funding needs stage None, and every closing path leaves a final stage [inferred].
- **Equivocation.** An adjudicator or a party that signs two conflicting messages for the same turn gets whichever lands first; the other reverts. That is the signer's own act and stays on the signed record (D26).
- **Malleability.** Solady's ECDSA path accepts high-`s` and 64-byte (EIP-2098) forms (`SignatureCheckerLib.sol:91-104`), so two byte strings can verify one message. No state is keyed by a signature's bytes, so this gives no replay [inferred]. Recorded as RR-4 in [`known-issues.md`](known-issues.md).

## Integer bounds

- `price + fee` in 256 bits (checked; panics on overflow), then refused above 2^120 − 1 (`:122-125`). CPP stores `uint120`.
- Deadlines are `uint64`; every sum is in 256 bits (`:472`, `:480`, `:487`), so none overflows. `fallbackBy <= 253,402,387,139` and `appealDecideSec <= 2^32 − 1` keep `t1` and every decision time within `uint40`, and the expiry is checked against `uint48` (`:125`).
- `uint48(t.timing.fundBy)` at `:132` cannot truncate: `fundBy < fallbackBy <= LAST_TIMESTAMP < 2^48`.
- `uint40(block.timestamp)` at `:285`, `:290`, `:440` wraps only from 2^40 s (about year 36,812).
- `_fallbackRound` subtracts 1 from `judgeBy`, which is at least 3 for a funded deal.
- `_payOut`: `total` and `toSeller` are checked sums; `rest = maxAmount − toSeller` cannot underflow because `toSeller <= total == price <= maxAmount`.
- `seedTag` truncates to 144 bits on purpose (L-4, known).
- `DrandQuicknetBeacon._decompress` and `_sub` use `unchecked` two-word arithmetic: `+4` carries correctly, and `_sub` is called only with `a >= b` (after the `_lt` test at `:140`, and for `p − y` with `y < p`) [inferred].

## Dead and left-over code

Every error (11) and every event (15) declared in `IHoldbackRules.sol` is used [measured: grep of `revert` and `emit` in `HoldbackRules.sol`]. Every internal function, constant and library function in `src/` is read [measured by reading]. No import is unused. No `HoldbackBonds`, Permit2, `fileAppeal`, `expireAppeal`, `expireOffer` or `Expired` stage remains [measured: grep]. What remains of removed features is listed here; none is a defect.

| Item | Where | Kind | Why it stays |
| --- | --- | --- | --- |
| `MUTUAL_FEE_SHARE_BPS = 0` | `HoldbackRules.sol:37`; `IHoldbackRules.sol:297` | constant read by no code (I-2 remnant) | Kept as a public getter so the ABI stays (I-2, T-334); `Postings.fuzz.t.sol` fails if it leaves 0 |
| `Acceptance.bondReserved` | `HoldbackTypes.sol:77`; `ACCEPTANCE_TYPEHASH` `:229`; check `HoldbackRules.sol:160` | bond remnant | Part of the signed `AdjudicatorAcceptance` that `eip712.ts` signs; required to be 0 |
| `Timing.appealWindowSec` | `HoldbackTypes.sol:28`; check `HoldbackRules.sol:169` | party-appeal remnant | Signed format; required to be 0 |
| `Timing.disputeBy`, `disputeJudgeSec`, `disputeFallbackSec` | `HoldbackTypes.sol:31-33` | signed only, read by no check at the tag; the fixed build requires 0 (T-529) | Signed format shared with core |
| `Decision.appealGroundHash` | `HoldbackTypes.sol:124`; check `HoldbackRules.sol:282` | party-appeal remnant | Must be `keccak256("")` for the primary and the fallback; signed only for the appeal adjudicator at the tag, and `keccak256("")` at every role on the fixed build (T-529) |
| `Decision.encryptedKeysHash`, `beaconSourceHash`, `nonce`; the primary's beacon fields | `HoldbackTypes.sol:125-130` | signed only; on the fixed build the primary's beacon fields must be empty (T-529) | Signed format |
| `Money` library, one constant `ALL_BPS` | `HoldbackTypes.sol:477-479` | used once (`HoldbackRules.sol:136`) | A library for one constant; the bond and split helpers left with SC-7 |
| `Deal.t1` written on a first-instance accept or reject | `HoldbackRules.sol:290` | write that no later code reads (the deal is closed) | Read only by `dealOf`; documented in `IHoldbackRules.sol:108-110` |
| Single-line wrappers `_capture`, `_void`, `_releaseKey`, `_escalationRound` | `HoldbackRules.sol:500-563` | not dead; each is called | Names the money and key moves in one place |
| `Decider.Appeal`, `ROLE_APPEAL` | `IHoldbackRules.sol:101`; `HoldbackTypes.sol:185` | not dead | The appeal adjudicator still hears escalations |

## Hard rule: no admin keys

Confirmed by reading [measured]:

- No `owner`, role, `onlyX` modifier, `msg.sender` check, pause flag, freeze, blacklist or setter in `HoldbackRules.sol` or `DrandQuicknetBeacon.sol`. Every parameter is an `immutable` or a `constant`.
- No proxy and no upgrade path: neither contract inherits a proxy; no `delegatecall`, `selfdestruct`, `callcode` or inline `assembly` appears in `src/` [measured: grep finds only the comment at `DrandQuicknetBeacon.sol:13`].
- No `receive`, no `fallback`, no `payable` function: the contracts refuse ether.
- The contract holds no funds: CPP's TokenStore holds them, with this contract as operator.

The test that enforces it: `contracts/test/fuzz/NoAdmin.fuzz.t.sol` [measured: read; it passed in the clean-clone `forge test` at the tag, 2026-11-17]. It pins each ABI to a reviewed allowlist (`test_everyAbi_isItsReviewedAllowlist`, 22 entries for `HoldbackRules`, 5 for `DrandQuicknetBeacon`, `:70-131`), asserts no `"type":"fallback"` or `"type":"receive"` in the artifacts (`:189-190`), checks 24 forbidden admin selectors are absent and their calls fail (`:196-235`), fuzzes unknown selectors and plain ether transfers to revert (`:238-253`), and walks the runtime bytecode for `SELFDESTRUCT`, `CALLCODE` and `DELEGATECALL`, allowing `DELEGATECALL` only in CPP's fixed minimal-proxy TokenStore clone (`:263-296`). One gap in what it covers: the opcode walk skips trailing data only for the shapes it knows, so it depends on the compiler keeping constants as PUSH immediates; `DrandQuicknetBeacon` makes `P_LO` an immutable for that reason (`DrandQuicknetBeacon.sol:51-53`) [inferred].

## Static analysis: every result on in-scope files

"False positive" means the pattern the tool flags cannot occur or cannot do harm here. "Accepted" means the pattern is real but intended.

### Slither

| # | Detector (impact) | Where | Answer | Reason |
| --- | --- | --- | --- | --- |
| S-1 | `incorrect-equality` (M) | `HoldbackRules.sol:218` `d.stage == Stage.Held` | false positive | Enum comparison. The detector targets equality on balances an attacker can nudge; an enum has no such input |
| S-2 | `incorrect-equality` (M) | `:236` `role == H.ROLE_PRIMARY` | false positive | Constant role code set by `_turn` from state |
| S-3 | `incorrect-equality` (M) | `:247` (two results) `role == ROLE_PRIMARY`, `role == ROLE_FALLBACK` | false positive | Same |
| S-4 | `incorrect-equality` (M) | `:253` `s == Stage.Escalated` | false positive | Enum |
| S-5 | `incorrect-equality` (M) | `_turn` `:266`, `:268`, `:270` | false positive | Enum stages |
| S-6 | `uninitialized-local` (M) | `_payOut` `:396` `total`, `:397` `toSeller` | false positive | Sums that start at 0 by the language's zero-initialisation |
| S-7 | `unused-return` (M) | `_refundAll` `:513` `(, uint120 held,) = ESCROW.paymentState(...)` | accepted, as S-18 at `1430f77` | Only `capturableAmount` matters: CPP's `void` reverts when it is 0 (`AuthCaptureEscrow.sol:307-308`). The two other fields say nothing about what `void` returns |
| S-8 | `reentrancy-events` ×9 (L) | `_refundAll` `:516-517`; `_settleDecision` (3 results) `:311-321`; `reclaim` `:429-430`; `earlyAccept` `:348-353`; `_payOut` (2) `:406-414`; `mutualSettle` `:385-387` | accepted | Events after a call to CPP's `capture` or `void`. In every path the deal's stage is written before the call ("Reentrancy ordering around the escrow calls", above); CPP is `nonReentrant`; `TOKEN` is fixed at deploy. A re-entry would find the deal closed and revert `WrongStage`. Event order inside one transaction changes no state. Indexers see the events of one transaction together |
| S-9 | `timestamp` ×10 (L) | `agreeAndFund` `:156-157`; `decide` `:217`, `:235`; `_turn`; `earlyAccept` `:338`; `mutualSettle` `:369`; `reclaim` `:428`; `triggerFallback` `:438`; `triggerDefault` `:451`, `:453`; `_acceptDelivery` `:528`; `_refundAll` `:512` | accepted | Deadlines are the design (ADR-0002). Each opposing pair splits time at one instant (`now < X` vs `now >= X`; `docs/audit/state-model.md` §6). A proposer's few seconds of drift sit inside the windows the parties choose |
| S-10 | `cyclomatic-complexity` (I) | `decide` `:212`, score 12 (18 at `1430f77`) | accepted | One entry point for three roles; lower than before |
| S-11 | `low-level-calls` ×2 (I) | `DrandQuicknetBeacon.sol:87-88`, `:163` | accepted | EIP-2537, MODEXP precompiles have no Solidity interface. Every result's length is checked, so a missing precompile refuses (`:89`, `:164`) |
| S-12 | `naming-convention` ×17 (I) | immutables and getters in `UPPER_CASE`: `HoldbackRules.sol:50-62`, `IHoldbackRules.sol:287-322`, `DrandQuicknetBeacon.sol:53` (`P_LO`) | accepted | Style. The names are the ABI, pinned by `NoAdmin.fuzz.t.sol`'s allowlist |
| S-13 | `too-many-digits` ×8 (I) | `DrandQuicknetBeacon.sol:30-46` (the `PK_*` and `NG_*` words) | accepted | BLS12-381 curve constants; they must equal the published values |

### Aderyn

| # | Detector | Where | Answer | Reason |
| --- | --- | --- | --- | --- |
| A-1 | H-1 `abi.encodePacked()` hash collision ×8 | `HoldbackTypes.sol:212, 213, 217, 228, 243, 252, 260, 262` | false positive | Each packs compile-time type strings into an EIP-712 type hash; no caller chooses an input |
| A-2 | L-1 internal function used once ×4 | `HoldbackTypes.sol:285` `timingHash`, `:291` `adjudicationHash`, `:395` `roleHash`, `:402` `outcomeHash` | accepted | One function per EIP-712 struct, mirroring `eip712.ts`; style |
| A-3 | L-2 large numeric literal ×2 | `DrandQuicknetBeacon.sol:65` `250_000`; `HoldbackTypes.sol:478` `10_000` | accepted | Named constants already |
| A-4 | L-3 literal instead of constant ×13 | `DrandQuicknetBeacon.sol:84, 100-102, 112, 116, 130-131, 136, 158` | accepted | Byte lengths and offsets of EIP-2537 and RFC 9380 encodings (48, 64, 128), and the curve's `b = 4`; each line says what it is |
| A-5 | L-4 loop contains `revert` ×1 | `HoldbackRules.sol:398-403` `_payOut` | accepted | Both parties sign the payout list; a bad entry reverts only that settlement. The loop has no external call |
| A-6 | L-5 unchecked return ×2 | `HoldbackRules.sol:202` (`deliver`), `:219` (`decide`) ignore `_acceptDelivery`'s hash | false positive | `_acceptDelivery` stores the hash itself (`:532`); `decide` reads `deliveryHashOf[id]` at `:228`. Only `earlyAccept` (`:340`) needs the returned value |
| A-7 | L-6 public function not used internally ×1 | `DrandQuicknetBeacon.sol:76` `roundAt` | accepted | Called by `HoldbackRules` through the interface and by off-chain verifiers |
| A-8 | L-7 unused state variable ×1 | `DrandQuicknetBeacon.sol:65` `PAIRING_GAS` | false positive | Used at `:88` |

No tool result is a defect.
