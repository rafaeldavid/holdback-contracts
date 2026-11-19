# ADR-0039: Changing a funded deal by agreement: a waiver first, a replacement for new terms, one signed note for both

- **Status:** Proposed, 2026-11-18 (D78). Needs Rafa, except two points he decided on 2026-11-18 (section 4): the default tie between a replaced deal and its successor, and the note's carrier, a hash in the settlement's existing `nonce` for now, with a named field and an event later in a contract version of its own. Nothing here is built.
- **Raised by:** T-524, roadmap row N188. Rafa, 2026-11-18: "contracts / API need to allow for mutually agreed contract amendments seamlessly. It needs to be a normal path of trade". The same day, through the coordinator, he asked to:
  - weigh "the API help sign an atomic transaction that refunds, creates new escrow, and sends money from first contract back to buyer to new contract atomically";
  - decide the tie: "Let's do the default as transaction data which is signed by both buyer and seller original keys";
  - challenge his own recommendation "with proper strategy and trade theory";
  - and say "How would we account for a waiver?".
- **Research:** [`docs/research/2026-11-18-amending-a-funded-deal.md`](../research/2026-11-18-amending-a-funded-deal.md): how a deal's terms bind today, with line references; what the gate before signing removes; the local-chain test of a replacement in one transaction; trade practice and theory, with sources.
- **Builds on:** ADR-0001 (neutrality), ADR-0002 (the hold), ADR-0012 (key release), ADR-0015 (user choice), ADR-0016 (the commitment ID), ADR-0024 (per-deal keys), ADR-0029 (delivery binding), ADR-0031 (the phase-one contracts), ADR-0037 (the hosted seller adapter); D26, D28, D29, D31, D32, D35, D77.
- **Amends:** no ADR.
- **Changes when built, by later tasks:** `spec/` (one new signed type, `SettlementNote`, and two routes, in an additive version), `apps/operator` and `apps/demo-cloud`, `examples/` (the seller adapter, a buyer command, the deal record and the evidence check), `apps/hosted-sellers`, the guides under `site/`, `fixtures/`, `contracts/test/` (tests only), `docs/neutrality.md`. No change to `contracts/src/`. This record changes no code.

Labels: **measured** (read at the cited line: `contracts/src/` at the tag `contracts-phase-one-1`, commit `27ab44e8`; everything else at `origin/main` `1c9ffacf`; or run as cited), **documented** (a doc or source states it), **recalled** (known to the author, not opened on 2026-11-18), **inferred**, **guessed**.

## Summary

**The recommendation, in five lines:**

1. **A waiver comes first.** When the work fails a check and the buyer still wants it, both parties sign the settlement that names the held work and releases its key. The contracts already pay it. The hosted seller must offer it instead of waiting until the deadline. It would have closed Crow's own scan in one step [inferred].
2. **A replacement handles a real change of terms.** One Multicall3 transaction refunds the old deal by agreement and funds a new deal from that refund, or does nothing. The frozen contracts did this on a local chain, 4 cases of 4 [measured], so it needs no contract change.
3. **One signed note serves both.** The settlement's `nonce`, which both original keys sign and no contract reads, carries the hash of a small `SettlementNote`. For a waiver it names the held delivery and the waived checks; for a replacement, the successor deal. It sits in the transaction's data, as Rafa decided, and the receipt holds its text.
4. **An in-place variation,** which keeps one commitment ID, is designed (section 9) and not built until measurements ask for it.
5. **No wrapper for today's four moves.** T-503's refund and T-501's job takeover become steps inside the replacement.

**What Rafa decides:** section "Open points for Rafa", four questions. **What stands of his decisions:**
- the atomic replacement;
- the default public link signed by both original keys;
- the note as a hash in the settlement's `nonce` for now, with a named field and an event later in a contract version of their own [the carrier verified, measured].

One part changes: the replacement is not the first answer. The waiver is (section 7).

## Context

### The need

Both pilot deals so far had a finished report refused by the deal's signed checks while the deal was `Held` with nothing delivered [measured, the private record]. Each fix took four moves: new terms, a redeploy of the hosted seller, a second deal that takes over the finished job, and a full refund of the first deal that both parties sign. The second case's run sheet has six steps by a person [measured, private].
- **In the first case** the seller's own conversion was also wrong: it read no artifacts, so the held report was empty. A seller fix and a redeploy were needed whatever the terms said. With the conversion fixed, the report still failed two checks on findings that the buyer later accepted [measured, private].
- **In the second case** the seller's check refused bytes that later passed the corrected checks unchanged: the same hash and the same pointers [measured, private].

So the work was acceptable and its form was off.

**The gate before signing removes some of the need, not all.** Since 2026-11-18 no deal is signed until its checks have run on one real delivery from that seller. It would have caught the first case [inferred]. It would not have caught the second: its checks had met a real report from the same seller, and the new report had two shapes of finding that report lacked [inferred from the measured causes].

### How a deal's terms bind today

Each line is measured; the research note has the full walk.

- **The commitment ID is the hash of the whole terms** (`HoldbackTypes.sol:307`), recomputed by every entry point. A changed field is a different deal.
- **The hold is keyed to values from the terms** (`HoldbackRules.sol:117`, `:138`, `:479`). The escrow identifies a payment by the hash of that struct, authorizes it once, and cannot raise its amount or its expiries [documented: `base/commerce-payments` docs].
- **Enforced fields:** the parties, the money addresses, the token, the price, the fee, the adjudicators, the timing, and the policy and registry hashes (`HoldbackTypes.sol:36-44`, `:410`). **Signed-only fields** include `acceptanceHash`, which covers the checks and the rubric.
- **One delivery, written once,** before `deliverBy` (`HoldbackRules.sol:47`, `:69`, `:168`, `:524`). The first decision is final (ADR-0031).
- **The settlement both parties sign** (`HoldbackRules.sol:360`) pays any split of the price to the two money addresses and returns the fee to the buyer. In `Held` it may name a delivery the buyer holds and release its key. Its `nonce` enters only the signed digest (`HoldbackTypes.sol:439-458`); no other line of `HoldbackRules.sol` names it. Replay is stopped by the deal's stage.
- **A reader can already tell how a deal ended.** `MutuallySettled(id, keyReleased)` marks a settlement, and `KeyReleased` carries `path`, `KEY_DECISION` 0 or `KEY_MUTUAL` 2 (`IHoldbackRules.sol:205-224`). So a release by agreement reads differently from a release on the checks.
- **Every entry point is permissionless,** and the rules contract never reads `msg.sender` (`docs/neutrality.md`, the operator row).
- **The hosted seller, when a check fails,** delivers nothing, alerts, and waits for a fixed report until `deliverBy` (`site/ref/seller-adapter.txt:12`). Its routes are `ready`, `job` and `refund` (`examples/seller-adapter-core.ts:1974-1981`). None hands the held work to the buyer.
- **The API takes the caller's `nonce`** for a settlement (`POST /v1/prepare/settlement {"commitmentId", "nonce", …}`, `site/ref/after-funding.txt:10`) [documented].
- **The commitment schema** has no field that names another deal and allows no extra fields [measured by the coordinator, 2026-11-18].

## Decision

### 1. Three instruments, lightest first

Contract practice separates three ways to change a deal after it is made. Crow uses them in this order.

| Instrument | When it is the right tool | In Crow, on the frozen contracts |
| --- | --- | --- |
| **Waiver** | The work is acceptable and the form is off: the buyer accepts it as delivered | The settlement both sign, naming the held work and releasing its key. Exists |
| **Variation** | The same deal goes on under changed terms, before the work is delivered | Not possible in place: the terms are the deal's name and the hold's key. Designed for a later build (section 9) |
| **Replacement** | The terms must change: new checks for new work, a price, a deadline, a scope, an adjudicator | One transaction that refunds the old deal and funds a new one. Works today [measured] |

The frozen contracts force the replacement wherever a variation would otherwise fit. That is acceptable: the replacement reuses only audited paths, and the variation can follow if measurements ask for it (section 9).

### 2. The waiver

**What it is, step by step:**

1. **The seller's own check lists the defects.** The hosted seller runs the signed checks before it delivers (`site/ref/seller-adapter.txt:12`). On a failure it signs the delivery without posting it, and offers the buyer a waiver: the failing checks, each with its pointer (for example `report` at `/artifacts/44`), the delivery's hash and the seller-signed settlement.
2. **The buyer sees the defects, not the content.** The buyer gets the signed delivery's fields with the list of envelope hashes, enough to recompute the delivery's hash, and never its own envelope's ciphertext. Whoever holds that envelope can open the work, so a buyer holding it could read the work, decline, and take its refund at `deliverBy`: the free look ADR-0012 exists to prevent [inferred; the review of 2026-11-18]. The buyer's tools show each failing check and where it fails, and stop for the principal's yes. This is how a bank examines a letter of credit: it reads the documents, never the goods.
3. **Both sign one `MutualSettlement`:** `hasDelivery` true, the delivery's hash, the price to the seller (or any split the parties agree), `releaseKey` true, and `nonce` the hash of the waiver's note (section 4). The buyer countersigns and hands its signature back. **The seller submits**, with the delivery and the key proof that carries the buyer's envelope (`HoldbackRules.sol:379-381`). So the payment and the key's release land in one call. A buyer that never countersigns changes nothing.
4. **On chain** the deal ends `Settled`, with `KeyReleased` on path `KEY_MUTUAL`. A reader of the chain sees a release by agreement. A reader of the note sees which checks were waived. The receipt carries the note's text.

**Why neither pilot used it.** The money path existed ("settling late work", `site/ref/after-funding.txt`), and the kit's case 9 ran it to `Settled` with the key released [measured, private record]. The hosted seller never offered it. On a failed check it holds the work, alerts and fetches the result again every 600 s until `deliverBy` [measured, private record]. No route hands the signed delivery to the buyer [measured, above]. So nothing was held for the buyer to accept.

**The smallest change that makes it the first offer:**
- The hosted seller, on a refused check, keeps the signed delivery. It serves the waiver offer at `GET /deals/{commitmentId}/waiver`, as public as `/health`, which already lists each refused deal's failing checks and pointers with no report content (`site/ref/seller-adapter.txt:44`).
- It signs the settlement on `POST /deals/{commitmentId}/waiver`, behind the ready credential, or at once when its configuration says so.
- A buyer command shows the offer, stops for the principal's yes, and countersigns. `POST /deals/{commitmentId}/waiver/accept` takes the buyer's signature, and the seller submits with the envelope.

No new deal, no new contract code, and nothing to tie.

**Would it cover the need?** It covers the second measured case, whose bytes later passed unchanged. It covers the first once the seller had fixed its own conversion, which no change of terms could do [inferred]. It does not cover a change of the work itself (a new scope, a later deadline, a different price for more work). That is the replacement's job.

### 3. The replacement

**What may change:** everything, since the new deal is a new offer the seller signs, the new primary accepts, and the buyer agrees to and funds. The checks refuse only what settlement cannot process (D31). The price may rise only up to what the payment address holds after the refund lands; above that the whole transaction reverts [measured]. The tools keep the parties, money addresses and adjudicators the same unless the request changes them.

**The messages:** only today's.

| Message | Signed by | Fields that matter here |
| --- | --- | --- |
| `MutualSettlement` on the old deal | the old deal's buyer and seller keys | No delivery, the whole price to the buyer's payment address, `releaseKey` false, `nonce` the note's hash |
| `CommitmentTerms` of the new deal | the seller | The new terms in full |
| `AdjudicatorAcceptance` | the new primary | As for any offer |
| `Agree` | the new deal's buyer key | As for any offer |
| `ReceiveWithAuthorization` | the buyer's payment address | The new hold; valid until the new deal's `fundBy` |

**One transaction.** The operator, or either party, sends one Multicall3 `aggregate3` call with no failure allowed: `mutualSettle` on the old deal, then `agreeAndFund` on the new one. On a local chain against the frozen contracts [measured, 2026-11-18, 4 of 4 passed]:
- the old deal ended `Settled` and the new deal `Held`, funded from the refund alone;
- with a wrong signature on the new agreement, the whole call reverted, and the old hold stayed intact;
- with a new hold above the refund and the wallet, the whole call reverted;
- the refund alone still settles, as today's agreed refund does.

Multicall3 already has code on Sepolia at `0xcA11bde05977b3631167028862bE2a173976CA11` [measured: `eth_getCode`, 2026-11-18]. Nothing checks the caller in a way that breaks the batch: the rules contract never reads `msg.sender`. It is the escrow's operator for every payment, since `PaymentInfo.operator` is the rules contract itself (`HoldbackRules.sol:117`), and the collector pulls the buyer's ERC-3009 authorization inside `agreeAndFund` [measured by the test].

**The order of signing, so neither side is exposed:** the seller signs first, the refund and the new offer, through its replace route, which also moves the finished job (T-501's step). The buyer's tool signs the new funding only once it holds the seller-signed refund. It then submits the whole batch itself, with no failure allowed, and never hands the funding out alone. Then:
- the seller's signed refund can only return the buyer's money, which a failed check would also have done;
- the buyer funds the new deal only inside the batch, so it never funds twice, and the old deal never stays live beside a funded new one;
- the buyer's funding authorization expires at the new `fundBy`, so a batch the buyer never sends lapses.

A buyer that hands the funding to someone else alone takes a real risk. If the funding lands without the refund, the old deal stays live on its old terms: the seller could deliver into it, and the buyer would pay the old fee on a reject or pay twice on an accept. That stays within the signed terms, so neutrality holds, but money is at risk [inferred]. So the rule belongs in the buyer's signer, not in advice.

**Approvals by a person:** the seller's one call and the buyer's one yes, against six steps today [inferred].

**What is lost against a true variation:**
- **The deal's ID changes.** The note ties the two (section 4).
- **Gas:** about 840,000 for the batch on Sepolia, a settlement and a funding measured separately [inferred].
- **No second fee.** The old fee returns to the buyer, and only the new deal is judged.
- **The delivery count starts again.** That is the point: the new terms judge a delivery made under them.
- **The adjudicator** accepts the new offer like any offer.

### 4. The note, and the tie Rafa decided

**Decided by Rafa on 2026-11-18:** "Let's do the default as transaction data which is signed by both buyer and seller original keys. So that reputation public is easier to calculate, both for buyer and seller. They will care if someone reading the data can trace they do complete commitments".

**How it is carried: one small signed statement for both the waiver and the replacement.**

```
SettlementNote(string kind, bytes32 deliveryHash, string[] waivedChecks, bytes32 successor, bytes32 salt)
```

- `kind` is `"waiver"` or `"replacement"`. A waiver fills `deliveryHash` and `waivedChecks`, the IDs of the failing checks as the terms name them. A replacement fills `successor`, the new deal's commitment ID. `salt` keeps every note unique.
- The settlement's `nonce` is the note's domain-free EIP-712 struct hash, as the commitment ID is for the terms (ADR-0016). The two original keys sign the settlement, so they sign the note. The frozen contract checks those signatures.
- **"Original keys"** are the old deal's `buyer` and `seller` as its terms name them. In an open deal these are the agents' own keys. In a private or judgment-level deal they are its per-deal keys (ADR-0024), so a reader learns only that two deals belong together, not who owns them. Private deals stay deferred (D70).
- **The note's text is public by default.** The submitter adds it to the same transaction as one more `aggregate3` call to the identity precompile at address `0x04`, which returns its input and changes nothing (about 200 bytes, under 10,000 gas) [inferred]. The receipt and the deal record carry it too. No deployed contract turns it into a log; a later build can (below).
- **Who writes it, and why that is safe:** the submitter writes the text, but only a note whose hash both parties signed counts. A transaction without the text still settles. A reader then has the hash, and the receipt supplies the text.
- **How a reader checks it, from the transaction's input alone:**
  1. Decode the batch.
  2. Hash the old terms to get the old commitment ID.
  3. Recover both settlement signatures under the deployment's domain, and match them to the old terms' `buyer` and `seller`.
  4. Hash the note text and compare it with the settlement's `nonce`.
  5. For a replacement, check that `successor` is a funded deal, normally the one funded in the same batch. If the halves were sent apart, the successor's funding is a later transaction, and the reader looks it up by ID.

  `examples/evidence.ts check` reports "replaced by", "replaces" or "settled under waiver of checks …".
- **How the parties opt out:** both sign one nonce, so either party can refuse a tied settlement. The tools then offer a random nonce, with no note, which both sign instead. A party that insists on no tie cannot be made to sign one; it can only decline the settlement. A link only the parties hold is also possible: they sign the note's hash and keep its text private, and show it to whom they choose.
- **The tension, recorded without reopening it:** D35 makes minimal disclosure the general default. This one link is public by default, by Rafa's choice, because both deals and their settlements are already public, and the parties gain from a traceable completion.
- **Decided by Rafa on 2026-11-18, the carrier** ("Yes, all six", accepting the coordinator's summary): for now the note rides as a hash in the settlement's existing `nonce`, with no contract change. A named field and an event come later, in a contract version of their own, so the next build (the outside scan's fixes, D77) stays a pure fix with nothing new mixed in.
- **Why the carrier holds** [measured]:
  - The API takes the caller's nonce: `prepare/settlement` accepts any 32 bytes of hex (`apps/operator/src/prepare.ts:255-259`, `:835`). The operator derives no nonce (D39).
  - The reuse check covers only an offer's terms (`packages/core/src/state.ts:233`), and a salted note never repeats.
  - The contract reads the nonce only inside the signed hash (`HoldbackTypes.sol:439-458`), and replay is stopped by the deal's stage.
  - A reader recovers it from the call data of `mutualSettle`.
- **The cost in clarity:** a field named `nonce` carries meaning. The guides call it "the settlement's note hash, in the `nonce` field". The later contract version names it `noteHash` and emits it in `MutuallySettled`.
- **What one transaction cannot hide:** whatever the parties choose, anyone reading a replacement's transaction sees both deals in it. The parties can avoid that only by sending the refund and the new funding apart, which gives up the atomic guarantee.

### 5. Work already done

| Situation | Rule | Who pays |
| --- | --- | --- |
| The seller's check failed; work held, nothing posted (both pilot cases) | Offer the waiver first; replace if the terms must change | The waiver pays the agreed split; the fee returns to the buyer |
| Work signed and held back past `deliverBy` | The waiver still works in `Held` until the operators' reclaim lands, one to two minutes after `deliverBy` | As agreed |
| A delivery posted, judgment in progress | The parties may settle by agreement, as today; no replacement from the tools | As agreed |
| A decision made, a key released, or a settlement landed | Final; a new deal if the parties want more | — |
| A reject | Final (D28); a new deal may take the finished job (T-501) | The reject paid its fee |
| Gas | The sender pays; today the operators sponsor it | — |

**Defaults when the parties say nothing:** the waiver pays the whole price to the seller; a replacement copies every unchanged field and gives fresh deadlines from the same windows; the note is published.

### 6. What can go wrong, the rule that stops it, and the test that proves it

| Threat | Rule | Test |
| --- | --- | --- |
| One party waives or replaces alone | Both signatures on the settlement; the new deal needs the seller, the primary, the buyer and the payment address | `attack.replace-one-signature`, `attack.waiver-one-signature` |
| An operator invents or alters one | It cannot sign for a party; each party rebuilds what it signs (`examples/verify.ts`) | `neutrality.operator-lies-in-prepare`, extended |
| An operator refuses | Either party submits through Multicall3 or straight to the contract | `neutrality.replace-operator-refuses` |
| A party withholds its half, or the halves are sent apart | The seller signs first, and its half can only refund. The buyer's tool signs the funding only once it holds that refund, and submits the whole batch itself | `attack.replace-split`: the buyer's signer never releases the funding alone |
| The refund replayed without the new deal | It applies once, since the deal leaves `Held`; alone, it is today's agreed refund | forge test, case 4 |
| A delivery or a timeout lands first | The refund needs `Held` with no posted delivery, so the batch reverts whole | `attack.replace-after-delivery`, `attack.replace-after-reclaim` |
| A false note | Only a note whose hash both original keys signed counts | `attack.note-forged` in the deal record's tests |
| A buyer opens the held work before a waiver, then declines | The buyer gets the envelope hashes, never its envelope; the seller submits the waiver with the envelope, so the key and the payment move together (ADR-0012) | `attack.waiver-free-look`: the waiver offer carries no buyer envelope |
| The buyer waives under pressure, or the seller presses for looser checks | Allowed: the buyer carries the burden of acceptance (D28, D32). The buyer's tools show each failing or loosened check and stop for the principal's yes, enforced in the signer | `attack.waiver-pressure`, `attack.replace-pressure` |
| Privacy | The note is public by default and optional; per-deal keys reveal no owner | — |

### 7. The challenge, and what survives it

Rafa asked for his recommendation to be argued against. Each challenge, with its verdict:

1. **Waiver before amendment.** In Mann's 500 letter-of-credit files the documents met the terms 27% of the time. The buyer waived the defects in every file but one, 59% of the defective presentations showed no failure by the seller, and over half the waivers came within one business day [documented: Mann (2000), as read for `docs/research/2026-11-18-reading-list.md`]. The trade's first answer to "the delivery does not match the terms" is a waiver on the same instrument. **Verdict: it holds.** The waiver comes first (section 2). It would have closed the second pilot deal, and the first once the seller fixed its own conversion.
2. **Three instruments, lightest first.** **Verdict: it holds.** The replacement is the heaviest of the three, and is kept for a real change of terms (section 1).
3. **The hold-up hazard.** Once one side has sunk its cost, cheap renegotiation invites pressure. A buyer can threaten to withhold a waiver unless the price drops, and a seller can press for looser checks after seeing a failure [recalled: Klein, Crawford and Alchian (1978); Williamson (1985); Hart and Moore (1988)]. If changing terms becomes the expected path, agents may sign loose terms and plan to fix them, which erodes D28. **Verdict: bounded.**
   - Every outside option is the signed terms running on. The seller can deliver and be judged, and the buyer gets its refund at the deadline.
   - No party can force a change, and the tools stop for the principal's yes each time.
   - The gate before signing aims at first-time passes. The health measures: the share of deals that pass at the first presentation should rise, and the share waived or replaced should fall, per seller and per kind of work. Both come from the receipts.
4. **Reputation from a default-public link.** An optional public signal unravels: once most pairs publish, a missing link reads as a failure, so the opt-out stops being free [recalled: Grossman (1981); Milgrom (1981)]. Two colluding keys can also make signed completions for the cost of gas. **Verdict: the default stands, with two limits.**
   - Never required, and published by default, as Rafa decided.
   - The receipt is the record of truth, not the link. A completion counts for reputation only as much as it cost: funds held, a fee paid to an independent adjudicator, a decision signed.
   - A note marks a waiver, so "paid under waiver" reads differently from "passed the checks", and an agreed release reads differently from an adjudicated one.
   - The time-tested home of an amendment's notice is the instrument itself: a credit's amendment travels with the credit. Here the note sits inside the old deal's own signed settlement, which is that home.
5. **Who pays for the restart.** Banks charge a fee on a discrepant presentation, which pays for clean documents [recalled]. **Verdict: no default fee.** A waiver's split can lower the price, and the settlement already allows any split. A fee is machinery the parties can write themselves (D32).

**What stands, changes or goes in Rafa's decisions:**
- **Stands:** the atomic replacement; a default public link signed by both original keys, in transaction data; the note's hash in the existing `nonce` until a contract version of its own names the field.
- **Changes:** the replacement is not the first answer. The waiver is. The same note records both.
- **Goes:** nothing.

### 8. What it removes

- **T-503's refund used as a restart** becomes a step inside the replacement. The standalone refund stays for a seller that will not deliver.
- **T-501's takeover of a finished job** becomes a step inside the replace route. It stays alone for a rejected or expired deal.
- **The hosted seller's redeploy** to change one deal's checks goes away. A redeploy still changes the checks offered to new buyers.

### 9. The in-place variation, designed and deferred

If replacements measure a cost (gas, or readers confused by two IDs), a contract build can add a variation that keeps the commitment ID:
- **The message:** `TermsAmendment {commitmentId, sequence, priorTermsHash, newTermsHash, expiresAt}`, signed by both parties, plus the primary's acceptance.
- **The contract:** `amend` runs in `Held` with no posted delivery and `now < deliverBy`. It stores the current terms hash and sequence, keeps the hold's funded amount and expiry, and emits `TermsAmended`. `Delivery` and `Decision` name the current terms hash.
- **What it may change:** the checks, the rubric and the deliverable; the deadlines within the funded expiry; the price down only; the fee within the hold; the adjudicators with the new primary's acceptance. Never the parties, the money addresses, the token or the delivery count.

**What would change this decision:** a measured share of replacements high enough that their gas or their second ID costs more than a contract change and its audit. Or a case the waiver and the replacement cannot serve.

## Alternatives considered

1. **The in-place variation now,** off chain first. It keeps one commitment ID and costs no gas. But before a contract build it can change only the checks, and it adds a new signed type, chain-following logic in the adjudicator, and trust that the adjudicator honours it. Deferred (section 9).
2. **The replacement first, with no waiver.** Rafa's first direction. It is heavier than the measured cases needed, and it puts every acceptable-but-off delivery through a new deal. Changed to second place.
3. **Keep the four moves and rely on the gate.** No new surface. But the gate would have missed the second case's new shapes [inferred], and each fix costs six steps by a person [measured]. Rejected.
4. **A separate signed message for the tie,** submitted beside the settlement. It needs a third signature step from each party. The `nonce` already carries a hash both original keys sign. Rejected.
5. **The tie in the new commitment,** as an optional field naming the replaced deal. It is signed only by the new deal's keys, not the original ones, and needs a schema change to `CommitmentTerms`. Rejected as the default; a later schema version may add it as an aid.

## Consequences

- An agent gets two steps, "waive" and "replace", built from messages it already signs, plus one new signed note.
- Readers can tell a release on the checks, a release under waiver, an agreed refund and a replacement apart, from the chain and the note.
- A replacement costs one batched transaction of about 840,000 gas on Sepolia [inferred]; a waiver costs one settlement.
- The hosted seller holds failing work for a waiver instead of only waiting for a fix.

## Litmus tests

- **Neutrality.** No single actor can waive or replace. An operator that refuses is bypassed through the contract or Multicall3. An adjudicator that declines a new offer leaves the old deal on its signed terms. The contracts are unchanged.
- **The hold.** Neither party can take a hold alone: the waiver and the refund need both signatures and pay only the two money addresses. If a replacement's batch fails, the old hold stays as it was [measured].
- **Defended judgment.** The checks still run first and their failures are what the buyer waives. No replacement after a delivery is posted, so none after a verdict.

## Open points for Rafa

1. **The order.** Recommended: waiver first, replacement for a real change of terms, the in-place variation only if measurements ask for it. The alternative is the replacement as the one path.
2. **The hosted seller's waiver offer.** Recommended: it holds failing work and offers the waiver on every refused check, and signs only on the ready credential. The alternative is to sign the waiver at once, so the buyer's yes is the only step.
3. **The note's text on chain.** Recommended: in the same transaction by default, through the identity precompile, with the receipt as the record. The alternative is the hash on chain and the text only in the receipt.
4. **The buyer's stop.** Recommended: the principal's yes on every waiver and every replacement. The alternative is to skip it for a replacement whose checks are only stricter.
