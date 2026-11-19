# ADR-0040: A seller makes a standing offer through a small contract of its own, and the rules contract stays as it is

- **Status:** Accepted, 2026-11-19 (D82). Rafa chose the direction on 2026-11-18 (section "The decision already made") and answered the two open points on 2026-11-19 (section "Open points for Rafa", with his answers). Nothing here is built.
- **Raised by:** T-544, roadmap row N196. Rafa, 2026-11-18, in the private design study T-532: "I think we need to fix this now so that there can be standing offers, instead of buyer-specific constraints".
- **Research:** [`docs/research/2026-11-18-standing-offers.md`](../research/2026-11-18-standing-offers.md): the design study's claims checked line by line, a scratch test of a seller contract against the unchanged rules contract (10 passed, 0 failed), and outside practice.
- **Builds on:** ADR-0001 (neutrality), ADR-0002 (the hold), ADR-0012 (key release), ADR-0016 (the commitment ID), ADR-0029 (delivery binding), ADR-0031 (the phase-one contracts), ADR-0033 (payout and payment addresses), ADR-0037 (the hosted seller adapter), ADR-0038 (mandates); D26, D31, D32, D35, D71, D73, D74, D81.
- **Amends:** no ADR. When built, it changes residual 13 of `docs/neutrality.md` for sellers: the operators read a contract seller's signature.
- **Changes when built, by later tasks (T-548 to T-552):** a new contract in `contracts/src/` beside the rules contract; `packages/core`, `packages/settlement/evm` and SimChain; `apps/operator`, `apps/adjudicator`; `spec/schemas/` (one widened type, schema v0.12); a new buyer command in `examples/` and its pinned bundle in `site/`; the card's schema `site/card.schema.json`; `fixtures/`; `docs/neutrality.md`. No change to `HoldbackRules.sol`, `HoldbackTypes.sol`, `IHoldbackRules.sol`, the EIP-712 domain or the terms' signed `schemaVersion`. This record changes no code.

Labels: **measured** (read at the cited line at `origin/main` `21bb4e54`, or run as cited), **documented** (a doc or published standard states it), **recalled** (known to the author, not opened on 2026-11-18), **inferred**, **guessed**.

## Summary

1. **A seller's address can be a small contract.** It answers ERC-1271 "yes" for terms that equal a template the seller's key signed, filled by a buyer, with the dates counted from the take. The rules contract already checks contract signers, and a scratch test passed 10 of 10 cases against it unchanged [measured].
2. **A fixed file can stand entirely.** One ciphertext and one delivery, approved once in the template, serve every take. This needs one core rule change: a delivery may leave out the buyer's envelope, and the buyer's key then comes with the adjudicator's accept [measured paths; the change inferred safe].
3. **Work done for each buyer** after funding still needs the seller once per deal, to work and to sign the delivery. Nothing is needed before funding.
4. **Work whose terms name the buyer's own scope** (a commit, file names) cannot be a template in this decision. Such sellers keep a per-buyer signer (open point 1).
5. **Anyone deploys the same contract** at one address computed from the seller's key, through the public deterministic deployer. Crow paying the gas gives Crow nothing.
6. **Off chain, the operators, the adjudicator and a new buyer command learn to read a contract signer,** and the API's `Signature` type widens for it: schema v0.12, a version bump. The contract, the domain and the signed encoding stay.

## Context

### What binds an offer to one buyer

- **The commitment ID is the hash of the whole terms,** and "the seller's signature over that ID is the offer" (`contracts/src/HoldbackTypes.sol:36-37`, `:307-333`) [measured].
- **The terms name the buyer** by its address, payment address and encryption key (`buyer`, `buyerPaymentAddress`, `buyerKeyHash`), and carry a `nonce`, a `createdAt` and five fixed dates (`HoldbackTypes.sol:22-34`, `:49-69`) [measured].
- **The chain first sees a deal at funding.** `agreeAndFund` checks the seller's signature over the ID, the primary adjudicator's acceptance and the buyer's agreement in one call (`HoldbackRules.sol:181-183`) [measured].
- **The delivery is signed for one deal:** its hash includes the commitment ID (`HoldbackTypes.sol:366-379`; `HoldbackRules.sol:530-531`) [measured].
- So today a seller signs once for each buyer, and again for each delivery. The seller adapter does this (`examples/seller-adapter-core.ts:1347`, `:1454`), and Crow hosts it for one design partner (ADR-0037) [measured].

### The fact that makes a seller contract possible

The rules contract checks every signature with Solady's `isValidSignatureNowCalldata` (`HoldbackRules.sol:567-571`). It recovers an ECDSA key for an address without code, and calls ERC-1271 `isValidSignature` for an address with code (`SignatureCheckerLib.sol:80-123`, Solady `5ea5d9f5`) [measured]. The repository already tests a seller wallet that signs terms and a delivery and is paid (`contracts/test/crosscheck/Erc1271Roles.t.sol:82`), and contract signers whose answer changes or burns gas (`Erc1271ChangingAnswer.t.sol`, `Erc1271GasBurn.t.sol`) [measured].

### The decision already made

**Decided by Rafa, 2026-11-18,** on the recommendation to take way A first: "let's go with this, since Crow can also offer deploying this on behalf of sellers anyways as a service / by default during setup". So standing offers are a small contract on the seller's side; the rules contract stays as it is; Crow may deploy that contract for a seller, as a service or during setup.

The same day he decided that a seller's default is work delivered after the hold is funded, with a finished file as one option. Another session is building that in the setup command (T-543).

## Decision

### 1. What the seller contract approves

**The contract** (`HoldbackStandingSeller`, name for the build). Its constructor takes one argument, `key`: the seller's own key address. It stores one mapping, `revoked[templateHash]`, and one flag, `retired`. It has no owner, role, pause, upgrade, fallback or receive. Its functions: `isValidSignature`, `revoke`, `retire`, and pure or view helpers that rebuild a take's terms.

**The template** is a full EIP-712 struct, `StandingOffer`, with its nested types, so a wallet shows its fields; the key signs it under the seller contract's own domain (name `HoldbackStandingSeller`, a version, the chain ID, and the seller contract as the verifying contract). The spike signed one opaque hash of the template instead, which a wallet cannot show (red team finding 2, measured); the build does not. It holds:
- `rules`: the one rules deployment the take is valid under;
- `expiresAt`: no take from this instant on;
- every field of the terms but six: `seller`, which the contract fills with its own address, and the take's five (below);
- the five dates as offsets in seconds from the take's `createdAt`, and `disputeBy` the same way when it is not 0; the windows (`appealWindowSec`, `appealDecideSec`, `disputeJudgeSec`, `disputeFallbackSec`) and `maxSubmissions` as they are;
- optionally, one standing delivery (section 2).

The template has no field the contract ignores, so one set of terms has exactly one template hash, and a revocation cannot be dodged by a second variant that differs only in an ignored field (red team finding 9, measured in its scratch test).

**The take's five fields,** filled by the buyer: `buyer`, `buyerPaymentAddress`, `buyerKeyHash`, a nonce seed, `createdAt`. **The terms' `nonce` is derived:** `keccak256(abi.encode(templateHash, seed))`. So every take's commitment ID binds the template it came from. Without this, two templates with equal terms give equal IDs, and a revoked template's standing delivery lands on the new template's take: the red team ran that attack against the spike, and the old file was delivered and paid (finding 1, High, measured). With the derived nonce, the old template's delivery is refused with `BadSignature`: the red team's two attack tests, rerun against the fixed spike, fail at that delivery [measured; T-548 keeps it as `attack.standing-delivery-from-revoked-template`].

**`isValidSignature(hash, sig)` says yes in exactly three cases:**

| `sig` | Says yes when | Covers |
| --- | --- | --- |
| 64 or 65 bytes | the key signed `hash` | everything the seller's key signs today: a settlement by agreement (a refund or a split), a per-buyer delivery, a per-buyer offer from the same address |
| a take: the template, the key's signature over it, the fill | the key signed the template; it is not revoked and the contract is not retired; `block.timestamp < expiresAt`; `createdAt <= block.timestamp`; and `hash` equals the digest, under the template's `rules` domain, of the commitment ID the contract computes itself from the template and the fill | one commitment per take |
| a standing delivery: the same, with another kind byte | the key signed the template; it carries a standing delivery; and `hash` equals the digest of that delivery for the commitment ID the contract computes | the fixed file's delivery for any take of that template, revoked or expired included, so a funded take always gets its delivery |

**What the rules contract adds** [measured, the scratch test]:
- **One commitment ID per take.** The fill's nonce seed and `createdAt` make each take's ID; a second funding of one ID reverts `WrongStage` (`HoldbackRules.sol:155`; `test_replayedTake_refused`). The seller contract needs no fill counter.
- **A bound on backdating.** The offer's expiry is `createdAt` plus the template's offer offset, and the rules contract refuses funding from that instant (`HoldbackRules.sol:156`; `test_backdatedCreatedAt_refusedByOfferExpiry`). So a buyer can backdate a take by less than the offer window, and the seller keeps at least `deliverBy − offer window` seconds to deliver [inferred from the two checks].
- **The order of the dates** and the values the contract can represent (`HoldbackRules.sol:166-180`). The seller contract refuses an offset sum above 64 bits as unrepresentable.

**How the contract computes the ID.** It calls the rules contract's own library, `HoldbackTypes.commitmentId` and `HoldbackTypes.deliveryHash`, and asks the named deployment for the digest (`typedDataHash`, `HoldbackRules.sol:111`). So there is one encoding of the terms, the audited one [measured in the spike, which uses both].

**Many offers, one seller.** One seller contract serves any number of templates: each is a signature of its key, and the contract stores nothing per template but a revocation. So a seller is one identity (key, contract address, payout address, card) with many offers. Each template carries a signed `offerId`, a stable string the seller chooses, equal to the card's `offers[].id` (`site/sell.txt`, step 9). A new price or new dates for the same offer are a new template with the same `offerId`; the seller's tool revokes the old one. The contract does not read `offerId`; it is there so a buyer, a catalog and a receipt name the offer the same way [the T-543 session's input, 2026-11-18; the card's ID measured there]. A feed of thousands of offers and a cart of several lines in one commitment are outside this decision: today a cart is several commitments.

**What it never does.** It never trusts a commitment ID, terms or a digest from the caller; it rebuilds them. It holds no money: the payout address is a template field, and a test showed the contract holds 0 after two paid takes (`test_twoTakes_oneStandingDelivery_bothPaid`). It refuses a template whose payout address is the contract itself, which has no function to move money out: the red team paid such a take into the spike (finding 8, measured), and terms that pay into a dead end are self-contradictory (D31).

**The key path's scope.** The first row approves any digest the key signs, so that every tool that signs Holdback messages today works unchanged. Holdback's own digests bind the seller's address through the commitment ID (`HoldbackTypes.sol:307-333`, `:366-379`, `:439-458`), so they cannot replay to another contract [measured]. Another application's digest signed by the key would replay across every seller contract of that key; the red team showed the contract approves one (finding 8, measured). Since the contract holds nothing and grants no allowance, such an approval reaches nothing [inferred]. The seller's tools use the key for this contract only, and the guide says so.

**`retire()`,** sent by the key or relayed with its signature, is one-way: from then on no new take is approved. It is the seller's answer to a leaked key, whose holder could otherwise sign templates with its own payout address under the seller's name for as long as they last (finding 9). It is not a pause: the key path and every standing delivery keep working, so funded deals settle as their terms say.

### 2. Delivery

**A fixed file stands entirely.** At setup the seller:
1. encrypts the file once with one content key, with envelopes for the three adjudicators the template names;
2. stores the ciphertext once, in an operator's store (up to 10 MiB, `apps/operator/src/server.ts:146-149`) or any content-addressed store (`docs/architecture.md:144`);
3. puts the delivery's fields in the template: the ciphertext's hash, the plaintext's hash and type, the envelopes' hash and one `submittedAt`, which nothing reads (`HoldbackTypes.sol:97-98`).

Then anyone posts the standing delivery for any funded take: the buyer, an operator, or the funding transaction itself, with `deliver` after `agreeAndFund` in one Multicall3 call. Two takes were served by one delivery body in the scratch test, and a delivery of another file was refused [measured, `test_twoTakes_oneStandingDelivery_bothPaid`, `test_deliveryOfAnotherFile_refused`]. **The seller acts once, at setup.**

**The one core change it needs.** Core and the operators require an envelope for the deal's own buyer in every delivery (`packages/core/src/state.ts:362-368`; `apps/operator/src/prepare.ts:723-726`) [measured]. Only a holder of the content key can make one, and the seller is offline. So a delivery may leave the buyer's envelope out. Then:
- the buyer's key comes with an adjudicator's accept: the primary wraps the content key to the terms' encryption key (`apps/adjudicator/src/service.ts:1045`), and the contract refuses an accept without it (`HoldbackRules.sol:310`) [measured];
- the buyer cannot accept early, and no settlement can release the key, because both need a key proof for the buyer's envelope (`HoldbackRules.sol:344`, `:380-381`). The call reverts, so the seller is never paid by these paths unless the buyer gets the key [measured: the red team's scratch test `test_rt_noBuyerEnvelope_earlyAcceptAndReleaseRevert`, both revert `BadKeyProof`, a forged proof included]. A settlement that pays the seller and releases nothing stays possible, signed by the buyer, as today;
- the formal model needs no change: its invariant is about whether the buyer holds the key, and the key still travels only with a release (`formal/Holdback.tla:824-828`) [the invariant measured; that no step of the model assumes a buyer envelope inferred, for T-550 to confirm].

**What one content key for every take means** [inferred]:
- the three adjudicators the template names can read every copy; they are the same three in every take. A primary that rejects every take and leaks the file is today's trust in the adjudicator, widened to every take (residual 6 of `docs/neutrality.md`);
- any buyer can pass the file on after it buys, which is true of any file sold;
- the envelopes cannot follow each deal, so they carry no time lock: phase one refuses a `beacon-round` unlock anyway (`packages/core/src/parse.ts:116-119`) [measured];
- the ciphertext's address (`ciphertext.uri`) is inside the signed ciphertext hash, so the template names one store. A store that loses the ciphertext stops judging for every later take. The adjudicator retries and never rejects for it (D81), and the deal ends by its timeouts in the buyer's refund. The seller re-uploads at the same address, or signs a new template. A content-addressed store makes the re-upload possible at any copy.

**Work done for each buyer after funding,** Rafa's default. The seller's worker watches the funded deals of its contract address, does the work, encrypts it to the three adjudicators and the buyer, and signs the delivery with its key (the first row of the table in section 1). Per deal it acts once, to work and deliver. It signs nothing before funding, so it may be offline when a take funds, as long as it delivers before `deliverBy`; otherwise the buyer reclaims [measured: `reclaim`, `HoldbackRules.sol:424-431`]. **The worker may decline any take** and let it end in the buyer's refund, with no penalty in phase one. That is its answer to a flood of funded takes: since an ERC-1271 answer is a view, no counter can cap takes, and an attacker's cost is its gas and its money held until `deliverBy` (red team finding 5) [inferred].

### 3. Work that depends on the buyer's input

**A template cannot cover it in this decision.** The pilot's security review names the buyer's scope in the deliverable ("Security review of the code at commit {{commit}}. Scope: {{files}}.") and in the checks: a `const` commit, a file `enum`, coverage bounds (`examples/seller-adapter.template.json:9`, `:197-208`, `:247`, `:274-280`) [measured]. The terms carry both as hashes of canonical JSON (`packages/core/src/eip712.ts:303-307`) [measured], so each buyer's scope changes two hashes.

Leaving the two hashes open would let a buyer order any work at the template's price. Filling them on chain would mean escaping JSON strings and keeping the canonical order inside the seller contract, for values the buyer chooses, and nothing would bound the size of the files a buyer names [inferred]. Both go against the smallest contract that can be reviewed with confidence.

**Unit pricing is the same question in a smaller form.** A price per unit needs a quantity the buyer chooses, and the quantity changes both the price, an enforced field, and the deliverable. The contract could multiply a bounded quantity by a unit price, but the deliverable's hash would still change per buyer [inferred]. So it waits with the slots below.

**So such sellers keep a per-buyer signer:** their own seller adapter, or the hosted one (ADR-0037). A standing seller can still make such an offer from the same address, signed with its key (section 1, first row). A later decision may add bounded slots that a buyer fills, if measured demand asks for it (open point 1).

### 4. Deployment for a seller with no ETH

- **One address, whoever pays.** The contract is deployed through the public deterministic deployment proxy at `0x4e59b44847b379578588920cA78FbF26c0B4956C`, which has code on Sepolia [measured: `eth_getCode`, 2026-11-18]. Its init code is the contract's creation code followed by the key, and the seller picks the salt (0 by default). So the address follows from the code, the key and the salt. Anyone computes it before deployment, anyone can deploy it, and a second deployment fails and changes nothing [measured, `test_anyPayerDeploysTheSameAddress`].
- **The payer gets no power.** The constructor's only argument is the key. No function changes the key, and none has an owner, pause or upgrade. A deployer that wanted a back door would have to deploy other code, which lands at another address [inferred from CREATE2].
- **The address proves the code.** A buyer that knows the key and the salt recomputes the address from the creation code's hash, which its own command pins. If it matches, the contract is this code with this key, and no other check of the code is needed [inferred from CREATE2]. It proves the code, not who the seller is: that still comes from the card's host, as today.
- **Three ways to deploy, none needing a Crow-run host:**
  1. the seller sends one transaction to the deployer from any account with ETH, through any RPC;
  2. the first buyer that funds directly sends the deployment first, in its own transaction, then funds;
  3. the operators' funding relay does the same when the seller address has no code yet, at the operator's gas. It needs no new route: it is one transaction before the existing `fund()` (`packages/settlement/evm/evm-settlement.ts:1266-1321`). This is how Crow deploys for a seller "by default during setup": the deployment lands with the seller's first sale [inferred]. A deployment costs about 1.9 million gas (9,430 bytes at 200 gas a byte, plus the call) [inferred], so an operator deploys only for a seller with a mandate it admits, under a budget it states, as its own policy (red team finding 7).
- **The deployment goes in its own transaction, never in the funding bundle.** A second deployment to an address that has code fails and burns the gas forwarded to it: the spike's second attempt used 1,040,431,767 gas of the test's limit [measured, `test_anyPayerDeploysTheSameAddress`]. In one Multicall3 bundle, a deployment that someone else made first, or two first takes in one block, would revert the funding [inferred]. So whoever deploys reads the address's code first and sends the deployment alone, skipped when the code is there; the funding follows. Two first takes close together then cost at most one failed deployment, never a failed funding.
- **The operators relay and never author.** The deployment carries only public code and the seller's key address; the template and every approval are the seller's signatures. The operator signs no message for the seller.
- **Before deployment, an offer can still be checked off chain:** the checker simulates the contract at its address (an `eth_call` with a code override) [inferred; the build tests it].
- **No upgrade, by design.** A new version of the contract is new code at a new address. The seller publishes it and revokes the old templates, or lets them expire.
- **A rules redeploy needs no new seller contract.** The template names the rules deployment, so the seller signs a new template, off chain and at no cost. The audit loop redeploys the rules contract routinely, so this matters.
- **Source verification** follows D71 (Sourcify) once per deployment [inferred].

### 5. The operators and the tools

**The off-chain check.** Today every off-chain check recovers an ECDSA key (`packages/core/src/eip712.ts:613-620`), and the node says contract signers "are not read" (`evm-settlement.ts:2003`) [measured]. The build adds one rule for every check of a signature by `terms.seller`:
- a 65-byte signature by an address with no code: recovered as today;
- any other case: ERC-1271 through `eth_call` on the latest block, with the code override of section 4 when the address has no code yet.

**Every such check moves to the rule,** not only the offer and the delivery. In the EVM node they are the offer (`evm-settlement.ts:936`), the delivery (`:1092`, `:1138`), a decision that carries the delivery (`:1212`), a settlement by agreement (`:1058`), the chain follower's reading of settlements (`:2065`, `:2326`) and the reading after a restart (`:2529`) (red team finding 3, measured); in the reference adjudicator, the delivery (`apps/adjudicator/src/service.ts:860`). A path left on ECDSA would refuse the key-path refund that section 1 promises, or leave a deal behind. The new buyer command uses the same rule. SimChain has no EVM, so core gains a pure function that builds a take's terms and decides a standing approval by the same rule. A differential test on the local chain pins it to the contract's answer. Once every path above uses the rule, residual 13's contract-signer case closes for sellers (`docs/neutrality.md:55`); buyers and adjudicators as contract signers stay as today.

**The API contract.** `Signature` is exactly 65 bytes (`spec/schemas/common.schema.json:15-19`), so a take cannot travel in today's offer [measured]. Schema v0.12 adds `PartySignature`, any non-empty hex byte string, and uses it for `signatures.seller` in the commitment and for the seller's `signature` in a delivery. Everything else keeps `Signature`. Old readers refuse a standing offer, which is right, since they cannot check it. The request-size limits that operators already apply bound its length.

**The buyer.** `site/buy.mjs` and `site/try.mjs` stay pinned and unchanged (`docs/tasks/T-475-setup-buyer.md:25`); they keep refusing a seller signature that does not recover (`examples/buyer-signer.ts:792-793`). A new command, `examples/take.ts`, bundled as `site/take.mjs` with its own pinned hash, takes a standing offer:
1. it reads the seller's card entry: the contract address, the key, the salt, the template and its signature;
2. it checks the template's signature against the key, and that the address follows from the key and the salt;
3. it fills its five fields, builds the terms with core's pure function, and shows them to its principal;
4. it posts them, waits for the adjudicator's acceptance, agrees and funds, as `buy.mjs` does;
5. for a fixed file, it posts the standing delivery itself; on the accept it opens the file with the key the adjudicator wrapped for it.

**The card.** `site/card.schema.json` gains an optional `standing` entry on each offer, under the offer's `id`, which equals the template's `offerId`. The card stays outside `spec/` (D74). The template's signature and the address check prove what the key signed and what code runs; who the key belongs to still rests on the card's host, as it does today.

**The seller.** A setup step, after T-543 lands, builds a template from the terms the seller chose, shows one filled example, signs the template with the seller's key, prepares the fixed file's standing delivery when there is one, and writes the card entry. It needs no ETH.

### 6. The adjudicator

The reference adjudicator reads offers from its settlement port and nobody posts to it (`apps/adjudicator/src/service.ts:442-446`) [measured], so it makes no difference that a buyer posts the terms. Its checks stay (`:475-595`, `:611-612`, `:722-733`) [measured]:
- it is the named primary, and it trusts the named fallback and appeal adjudicators;
- the policy and registry hashes are its current ones, and not withdrawn;
- the ID is the hash of the terms;
- the windows are within its caps, and the fee is in its token and at least its quote;
- its store holds every reference the checks name.

What changes for it:
- **It never trusts a posted seller signature itself.** It relies on the settlement port's contract-signer check (section 5), as it relies on `verifyTerms` today. For a delivery it uses the same check instead of an ECDSA recovery (`service.ts:860`).
- **A delivery without the buyer's envelope is valid,** and on an accept it wraps the key to the buyer as it does today (`service.ts:1045`).
- **It checks the buyer's encryption key at acceptance.** Today a key it cannot decode passes acceptance and fails only at the decision (`service.ts:497-522`, `:864-868`), after a per-buyer worker has done the work (red team finding 5, measured by reading). A standing offer lets anyone compose a take, so the check moves to acceptance.
- **Its acceptance still expires with the offer** (`acc.expiresAt`, checked at `HoldbackRules.sol:157`), so an acceptance for a take nobody funds dies within the template's offer window.
- **A template is a standing promise about its fee and policy.** When the adjudicator's quote or policy moves, it declines new takes (`policy_mismatch`, a fee below the quote), and the seller signs a new template.

### 7. Mandates, expiry and revocation

- **Admission.** A mandate names its agent by address (`spec/schemas/mandate.schema.json:20`), so a principal's mandate can name the seller contract [measured]. The operators look it up by address and club (`evm-settlement.ts:905-911`) and apply its caps to every take: a template above the price cap is refused at each take, not at publication [measured lookup; the per-take effect inferred].
- **A standing seller is one address across its takes.** The setup's default of a fresh key for each deal (D73) does not apply, so every take of a template links to one seller address in public. That is the seller's choice per template, and the guide says so (D35).
- **Standing offers are public deals in this decision.** A `private` or `judgment` deal seals its terms to the buyer and the primary at the offer, with the commitment ID as associated data (`packages/core/src/private.ts:5-7`, `:47`), so once per take, which an offline seller cannot do [measured]. Its signer is also a per-deal key with a `Delegation` certificate (`CLAUDE.md`, signed messages; ADR-0024), and a standing seller is one address. Private deals stay deferred through the pilots anyway (D70). So the template fixes `disclosure.level` to `public`, the seller's tool refuses any other level, and the operators refuse a take whose disclosure is not public. A later decision, with T-207's sealed terms, may let an adjudicator or the buyer seal per take.
- **A template ends four ways:**
  1. at its `expiresAt`, a required field with any value the encoding holds (D31); the seller's tool may warn about a far date, as advice;
  2. by `revoke(templateHash)`, sent by the key or relayed by anyone with the key's signature, at no cost to the seller [measured, `test_revokedTemplate_noNewTake_fundedDealStillDelivers`];
  3. by `retire()`, which ends every template of the contract at once and for good (section 1);
  4. in effect, when the rules deployment it names is no longer used, since no operator relays to it.
- **The most a seller can lose from a template it forgot** [inferred from the money paths]:
  - **money: none.** A seller funds nothing in phase one: the buyer's payment address funds the price and the fee (`HoldbackRules.sol:122-139`), there is no seller bond (ADR-0031), and an undelivered take ends in `reclaim`, which returns the whole hold to the buyer (`HoldbackRules.sol:424-431`, `:507-518`);
  - **obligations:** for work done per buyer, a duty to deliver to every take until the template ends, or a record of takes left undelivered;
  - **for a fixed file,** more copies sold at the template's price;
  - the bound is the template's own expiry and revocation (D26). With seller bonds, a later phase revisits this.
- **The seller's own check of each buyer.** `CLAUDE.md`'s rule on signed messages says the counterparty checks the agent's permission before it signs. A template signs for buyers the seller never sees, so the seller's check of each buyer's mandate is waived for that template, and the operators' check before they relay remains. A seller that must vet each buyer keeps a per-buyer signer (D32). This reading of the rule is open point 2.

### 8. What must change after all

| Layer | Change | Version |
| --- | --- | --- |
| The rules contract, `HoldbackTypes.sol`, `IHoldbackRules.sol` | none | none: the deployed build and the audit's scope stay |
| The EIP-712 domain ("Holdback", "0.8") and the terms' signed `schemaVersion` ("0.8") | none | none: no re-sign, no re-pin of `buy.mjs` or `try.mjs` |
| A new contract, the seller contract | new, beside the rules contract; its own domain | its own version string |
| `spec/schemas/` | `PartySignature` for the seller's terms and delivery signatures | **schema v0.12** (from v0.11), with this ADR |
| Core's delivery rule | the buyer's envelope becomes optional, with the consequences of section 2 | ships with v0.12 |
| The card's schema (outside `spec/`) | an optional `standing` entry | the card's own version |
| The formal model | none | none |

### 9. The attacks, and the tests the build needs

Each test has a place and an owning task. **Forge** tests go in `contracts/test/attack/StandingSeller.t.sol`, as functions named after the dotted name (`test_attack_takeReplayed` for `attack.take-replayed`). **Scenario** fixtures run on SimChain through core's pure function (section 5). **Local chain** tests run the operators and the adjudicator against anvil, as the EVM adapter's tests do.

| Attack | Defense | Test or fixture | Where, owner |
| --- | --- | --- | --- |
| A take changes a field the template fixes (price, payout address, an adjudicator, a check) | the contract rebuilds the terms itself, so any other field changes the digest | `attack.take-changes-a-fixed-field` (spike: `test_alteredTerms_refused`, measured) | forge, T-548; scenario, T-549 |
| A template binds the seller to terms it did not mean | the seller's tool shows one filled example before the key signs; the template's EIP-712 type makes the fields readable in a wallet; the template names one rules deployment | the setup step's test that the example equals `termsOf`; `attack.take-under-another-deployment` | local chain, T-552; forge, T-548 |
| A template signature reused for another seller contract with the same key | the template's domain names the seller contract | `attack.template-replayed-to-another-contract` | forge, T-548 |
| A replayed take | one commitment ID funds once | `attack.take-replayed` (spike, measured) | forge, T-548; scenario, T-549 |
| A take dated in the past, so the seller has no time to deliver | the rules contract's offer expiry bounds backdating to the offer window | `attack.take-backdated` (spike, measured) | forge, T-548; scenario, T-549 |
| A take dated in the future, or offsets that overflow | `createdAt <= block.timestamp`; an offset sum above 64 bits is unrepresentable | `attack.take-dated-ahead` (spike, measured); `attack.take-offsets-overflow` | forge, T-548 |
| Far-future dates in the template | the seller's own choice (D31); advice in its tool, no refusal | none needed | |
| A take with another disclosure level than public | the template fixes `public`; the operators refuse any other (section 7) | `attack.standing-take-not-public` | scenario, T-549 |
| A delivery of another file | the standing approval names one delivery's hashes | `attack.standing-delivery-other-file` (spike, measured) | forge, T-548 |
| One template's standing delivery used for another template's take, a revoked one included, even when the two templates have equal terms | the terms' nonce is derived from the template's hash, so the IDs differ; without it the attack worked against the spike (red team finding 1, High, measured) | `attack.standing-delivery-crosses-templates`; `attack.standing-delivery-from-revoked-template` | forge, T-548 |
| A second live variant of a revoked template | the template has no field the contract ignores | `attack.revoked-template-variant` | forge, T-548 |
| A template that pays into the seller contract | the contract refuses a payout address equal to itself | `attack.take-pays-the-seller-contract` | forge, T-548 |
| A leaked key signs templates with its own payout address | `retire()` ends every new take, one-way | `attack.leaked-key-after-retire` | forge, T-548 |
| A deployer keeps a back door | one constructor argument; no function changes the key; the address follows from the code | `attack.deployer-keeps-a-back-door`, and a selector allowlist test like `contracts/test/fuzz/NoAdmin.fuzz.t.sol` | forge, T-548 |
| A malformed blob, or one that burns gas | a failed decode fails the static call, which the rules contract reads as no (`Erc1271GasBurn.t.sol`) | `attack.standing-blob-malformed`, fuzzed | forge, T-548 |
| A flood of unfunded takes spends the seller's write budget, since the operator charges an offer to `commitment.seller` (`apps/operator/src/server.ts:369-372`) [measured] | an operator stores a take only with the buyer's Agree signature over its ID, and charges the take to that signer, so nobody can spend another address's budget; fresh keys each time are bounded by the operator's own limits per caller, as for any write | `attack.take-flood-spends-seller-budget`; `attack.take-flood-names-a-victim-buyer` | scenario, T-549 |
| A flood of funded takes against a seller of per-buyer work | the worker may decline any take, which ends in the buyer's refund (section 2) | `attack.funded-take-flood` | scenario, T-549 |
| A take with a buyer key nobody can decode, so the work is done and cannot be judged | the adjudicator checks the key at acceptance (section 6) | `attack.take-with-bad-buyer-key` | scenario, T-549 |
| A deployment someone else made first, or two first takes close together | the deployment goes alone, after a read of the address's code, and is skipped when code is there; the funding never carries it (section 4) | `neutrality.deploy-front-run-take-still-funds` | local chain, T-549 |
| Fake sellers drain the operator's gas through deployments | an operator deploys only for an admitted seller, under a stated budget (section 4) | `attack.deployment-gas-drain` | local chain, T-549 |
| A path of the node left on ECDSA refuses a standing seller's refund, or a decision that carries the standing delivery | every check of `terms.seller` uses the contract-signer rule (section 5) | `neutrality.standing-seller-refund-by-agreement`; `neutrality.standing-delivery-carried-by-decision` | local chain, T-549 |
| The adjudicator takes the offer itself and rejects | as today: the self-dealing bound | the existing `attack.adjudicator-self-dealing` | |
| The seller is offline from setup on | the take funds, the buyer posts the standing delivery, the primary accepts, the buyer opens the file | `neutrality.seller-offline-standing-take` | scenario, T-550 |
| One operator refuses the take | another operator relays it, as for any offer (`neutrality.operator-refuses`) | `neutrality.operator-refuses-standing-take` | scenario, T-549 |
| Crow's deployment never happens | the seller or the first buyer deploys | `neutrality.crow-deploys-nothing` | local chain, T-549 |
| The store drops the standing ciphertext | the adjudicator retries and never rejects for it (D81); the deal ends in the buyer's refund | `neutrality.store-drops-standing-ciphertext` | scenario, T-550 |

**A limit that is not new.** If every operator refuses, a buyer can still fund straight on the chain, but it needs the primary's acceptance first, and the reference adjudicator reads offers only through an operator (`apps/adjudicator/src/service.ts:442-446`) [measured]. Every offer has that limit today; a standing offer adds no new one. An adjudicator that takes terms from a party directly closes it.

**What the auditors would need** [inferred]: the seller contract (the spike has 136 lines and 9,430 bytes of runtime, measured), with its descriptions in an interface file (the repository's rule for new contracts); the full `StandingOffer` type with vectors generated in the repository, the derived nonce, `retire` and the payout refusal, as `contracts/test/unit/Vectors.t.sol` does for the terms; the attack tests above; a fuzzed decoder; a statement that `git diff` of the rules contract's sources is empty; and the rules contract's known issues on contract signers (ADR-0031 section 5, the changing-answer tests). Telling the firm that works on the contracts with Crow is Rafa's.

### 10. The build that follows

Five tasks, each with a task file. Sizes are guessed from the change recipes' budgets: about 6 pull requests and 1.1 million tokens in all.

| Order | Task | Kind | Done when | Size [guessed] |
| --- | --- | --- | --- | --- |
| 1 | [T-548](../tasks/T-548-standing-seller-contract.md): the seller contract | 7 | `forge test` passes every contract-level test of section 9, the rules contract's sources are unchanged, and size and gas are measured | 1 PR, 300k tokens |
| 2 | [T-549](../tasks/T-549-contract-seller-checks.md): operators and adjudicators check a contract seller's signature, schema v0.12 | 5 and 6 | a take posted to a local-chain operator is accepted, funded and settled, and a take with a changed field is refused before it is relayed | 2 PRs, 400k tokens |
| 3 | [T-550](../tasks/T-550-standing-delivery.md): a standing delivery without the buyer's envelope | 5 | a fixed file's standing delivery settles by the primary's accept and the buyer opens it; an early accept on it reverts | 1 PR, 150k tokens |
| 4 | [T-551](../tasks/T-551-take-command.md): the buyer's command that takes a standing offer | 4 | `site/take.mjs` takes a template from a card on a local chain and opens the file; `buy.mjs` and `try.mjs` hashes are unchanged | 1 PR, 150k tokens |
| 5 | [T-552](../tasks/T-552-publish-standing-offer.md): the seller's step that publishes a standing offer | 4 | from no ETH, a seller publishes a template and a card entry, and a buyer's first take deploys the contract and settles | 1 PR, 150k tokens |

T-548 and T-550 can run at the same time; T-549 needs T-548; T-551 needs T-549 and T-550; T-552 needs T-551 and T-543. None starts before Rafa answers D82's open points.

## Alternatives considered

### B. A new signed message in the rules contract

The seller signs a template once with its ordinary key, and a new function in `HoldbackRules` builds the terms from it and the buyer's fields.
- **For it:** the seller needs no contract of its own, only its key, and no deployment.
- **Against it:**
  - it changes the contract now in its outside audit, so the audit restarts on a new build, and a new world deploys;
  - it needs a new domain version, so every pinned command is re-pinned, and the formal model gains a step;
  - it puts template logic into the custody code every deal shares;
  - it still needs the schema change and the delivery rule change of this decision.
- **Size is not the obstacle.** The phase-one build's runtime is 20,502 bytes on chain and in its artifact (`docs/tasks/T-499-contracts-audit-ready.md:54`), so 4,074 bytes of the 24,576-byte limit are free [measured there]. A scratch `forge build --sizes` gave 20,455 bytes, which T-499 warns does not match the artifact. The design study's guess that a function may not fit does not hold.
- **Declined** as Rafa decided: the audit and the custody code weigh more than one deployment per seller, which anyone can pay.

### C. The seller's own address runs the template code (EIP-7702)

The seller's key delegates its address to the same template code.
- **For it:** the seller keeps its address, and no new address is published.
- **Against it:** a delegated address is checked by ERC-1271 alone, so every signature of that address goes through the delegated code (`contracts/test/crosscheck/Eip7702Signers.t.sol:53-60`) [measured]. Its storage persists across delegations, and the key can delegate to other code at any time [recalled]. The setup already gives each deal a fresh key (D73), so keeping one address buys little.
- **Declined for now.** The contract can be written so that a later decision can also use it as delegated code.

### D. The hosted per-buyer signer, as today

The seller adapter signs each buyer's offer in seconds (ADR-0037).
- **For it:** it exists, and it covers work that depends on the buyer's input.
- **Against it:** a program must be always on, which is what Rafa asked to remove.
- **Kept** for buyer-input work (section 3), beside standing offers.

### E. A factory or registry run by Crow

- **Against it:** more contract code to audit, and a Crow-run address in the deployment path, where the public deterministic deployer needs neither.
- **Declined.**

## Consequences

- A seller with a fixed file sells with nothing running after setup. A seller of work done after funding runs a worker that reacts to funded deals and signs nothing before them.
- Crow can deploy every seller's contract at its own gas and holds no power over any of them.
- The off-chain stack learns to read a contract seller. That also removes a known gap: a seller wallet's deal that today ends in a default refund because the operators cannot read it (`docs/neutrality.md:55`).
- A standing seller is linkable across its takes, by its own choice.
- One new contract enters the audit loop beside the rules contract; the rules contract's audit is unaffected.
- The API contract moves to schema v0.12, and old readers refuse standing offers.

## Litmus tests

- **Neutrality.** No single actor stops a valid take from settling. If one operator refuses, another relays the take, and the buyer can fund straight on the chain once it holds the acceptance (the limit in section 9 is as for any offer). If Crow deploys nothing, the seller or the first buyer deploys. If the seller is offline, a fixed file's standing delivery is posted by anyone. If an adjudicator fails, the fallback and the default apply as today. No actor can move held funds outside the terms: the rules contract is unchanged, and the seller contract approves only the exact terms its key signed as a template. The deployer and Crow's maintainers have no key in it. The fixtures in section 9 show each case.
- **The hold.** Funds are held, released and refunded by the unchanged rules contract. Each take is one commitment ID, funded once. Expiry, reclaim and the default work as today.
- **Defended judgment.** The checks and the panel are unchanged. A standing delivery is judged in each deal on that deal's own seed, and no panel is re-rolled. Work whose scope the buyer fills stays outside templates, so the checks never judge a scope a template did not sign.

## Open points for Rafa

1. **Work that depends on the buyer's input.** Recommended: such sellers keep a per-buyer signer (their adapter or the hosted one), and slots a buyer fills wait for measured demand. Or: a decision on bounded slots now, which grows the seller contract and its audit. **Answered by Rafa, 2026-11-19:** "If seller offer requires change / additional info from buyer, then it follows normal flow." The recommended reading holds.
2. **The seller's check of each buyer.** Recommended: a standing offer waives the seller's own check of each buyer's mandate for that template, and the operators' check before they relay remains (D32). Or: standing offers only for buyers the operators admit under a stated club rule. Either way, the rule on signed messages in `CLAUDE.md` would gain one sentence, which is Rafa's to write. **Answered by Rafa, 2026-11-19:** "Yes, waive it", to "Standing offers: waive the seller's own check of each buyer and keep the operators' check?". The recommended reading holds; the sentence in `CLAUDE.md` waits for his word on that file.
