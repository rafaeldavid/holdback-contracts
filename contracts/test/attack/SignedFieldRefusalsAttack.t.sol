// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHoldbackRules} from "../../src/IHoldbackRules.sol";
import {HoldbackTypes as H} from "../../src/HoldbackTypes.sol";
import {Base} from "../unit/Base.sol";

/// @title The signed-field refusals cannot be turned against a party (T-529 red team; an outside scan's G4)
/// @notice Who can trigger the three new refusals, and whether every stage keeps a way to settle after one. Written by
///         T-529's red team and kept as regression tests.
contract SignedFieldRefusalsAttackTest is Base {
    // ------------------------------------------------------------ a relayer cannot alter the refused fields

    /// A relayer that adds a beacon field to a valid primary decision gets a revert; the untouched decision settles.
    function test_relayerAddingAPrimaryBeaconField_cannotBlockTheSignedDecision() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        H.Decision memory good = _primary(t, id, H.OUTCOME_ACCEPT);
        H.Decision memory bad = _primary(t, id, H.OUTCOME_ACCEPT); // a separate copy, same signature
        bad.beaconRound = 1;
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        vm.prank(relayer);
        rules.decide(t, bad, _noDelivery(), "");
        bad = _primary(t, id, H.OUTCOME_ACCEPT);
        bad.beaconSourceHash = keccak256("drand-quicknet");
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, bad, _noDelivery(), "");
        rules.decide(t, good, _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
    }

    /// A relayer that adds an appeal ground to a valid escalation decision gets a revert; the untouched one settles.
    function test_relayerAddingAnAppealGround_cannotBlockTheSignedEscalationDecision() public {
        (H.Terms memory t, bytes32 id, uint64 at) = _escalatedBy(H.ROLE_PRIMARY);
        H.Decision memory good =
            _signDecision(t, id, _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_ACCEPT, at + 1), appealAdj, AP_PK);
        H.Decision memory bad =
            _signDecision(t, id, _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_ACCEPT, at + 1), appealAdj, AP_PK);
        bad.appealGroundHash = keccak256("wrong-outcome");
        // The ground check sits after the signature check (in _escalationDecision), so an altered ground fails there.
        vm.expectRevert(IHoldbackRules.BadSignature.selector);
        vm.prank(relayer);
        rules.decide(t, bad, _noDelivery(), "");
        rules.decide(t, good, _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
    }

    /// A funder that sets a dispute field on signed terms changes nothing on chain, and the signed terms still fund.
    function test_funderSettingADisputeField_cannotBlockTheSignedTerms() public {
        H.Terms memory t = _terms();
        bytes memory s = _sellerSig(t, SELLER_PK);
        H.Acceptance memory a = _acceptance(t, ADJ_PK);
        H.Agree memory g = _agree(t, BUYER_PK);
        H.Funding memory f = _erc3009(t, BUYER_PK);
        H.Terms memory altered = t;
        altered.timing.disputeJudgeSec = 1;
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        vm.prank(relayer);
        rules.agreeAndFund(altered, s, a, g, f);
        altered.timing.disputeJudgeSec = 0; // `altered` aliases `t` in memory: restore before the honest call
        vm.prank(relayer);
        bytes32 id = rules.agreeAndFund(t, s, a, g, f);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Held));
    }

    // ------------------------------------------------------------ liveness after a refusal, per stage

    /// Delivered: a primary that signs only beacon-carrying decisions leaves the fallback path open.
    function test_refusedPrimaryDecision_leavesTheFallbackPathOpen() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_ACCEPT);
        m.beaconValue = keccak256("x");
        m = _signDecision(t, id, m, adjudicator, ADJ_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
        vm.warp(t.timing.judgeBy);
        rules.triggerFallback(t);
        H.Decision memory fb = _beaconDecision(id, H.ROLE_FALLBACK, H.OUTCOME_ACCEPT, t.timing.judgeBy);
        rules.decide(t, _signDecision(t, id, fb, fallbackAdj, FB_PK), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
    }

    /// Held: a refused primary decision that carries the delivery lands nothing; the seller can still deliver.
    function test_refusedCarriedPrimaryDecision_landsNoDelivery_andTheDealStaysHeld() public {
        (H.Terms memory t, bytes32 id) = _funded();
        (H.Delivery memory d,) = _delivery();
        bytes memory dsig = _deliverySig(id, d, SELLER_PK);
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        m.beaconSignature = hex"01";
        m = _signDecision(t, id, m, adjudicator, ADJ_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, d, dsig);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Held));
        assertEq(rules.deliveryHashOf(id), bytes32(0));
        // The same carried call with empty beacon fields lands the delivery and settles.
        rules.decide(t, _primary(t, id, H.OUTCOME_REJECT), d, dsig);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }

    /// Escalated: an appeal adjudicator that signs only ground-carrying decisions leaves the default open.
    function test_refusedEscalationDecision_leavesTheDefaultOpen() public {
        (H.Terms memory t, bytes32 id, uint64 at) = _escalatedBy(H.ROLE_PRIMARY);
        H.Decision memory m = _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_ACCEPT, at + 1);
        m.appealGroundHash = keccak256("missing-or-wrong-key");
        m = _signDecision(t, id, m, appealAdj, AP_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
        vm.warp(uint256(at) + t.timing.appealDecideSec);
        rules.triggerDefault(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }

    /// The appeal-ground refusal also covers an escalation the fallback made.
    function test_fallbackEscalation_appealDecisionWithGround_refused_emptyGroundSettles() public {
        (H.Terms memory t, bytes32 id, uint64 at) = _escalatedBy(H.ROLE_FALLBACK);
        H.Decision memory m = _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_REJECT, at + 1);
        m.appealGroundHash = keccak256("wrong-outcome");
        m = _signDecision(t, id, m, appealAdj, AP_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
        m.appealGroundHash = keccak256("");
        m = _signDecision(t, id, m, appealAdj, AP_PK);
        rules.decide(t, m, _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }

    // ------------------------------------------------------------ classification by role and stage

    /// The fallback's beacon fields are untouched by the new check: a fallback with any beacon source still settles.
    function test_fallbackDecision_beaconSourceStaysSignedOnly() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        vm.warp(t.timing.judgeBy);
        rules.triggerFallback(t);
        H.Decision memory fb = _beaconDecision(id, H.ROLE_FALLBACK, H.OUTCOME_REJECT, t.timing.judgeBy);
        fb.beaconSourceHash = keccak256("not a source any node knows");
        rules.decide(t, _signDecision(t, id, fb, fallbackAdj, FB_PK), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }

    /// A primary escalation carried from Held with empty beacon fields still escalates (no misclassification).
    function test_carriedPrimaryEscalation_withEmptyBeaconFields_escalates() public {
        (H.Terms memory t, bytes32 id) = _funded();
        (H.Delivery memory d,) = _delivery();
        rules.decide(t, _primary(t, id, H.OUTCOME_ESCALATE), d, _deliverySig(id, d, SELLER_PK));
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Escalated));
    }

    /// The new beacon check runs before the signature check: an unsigned call reverts InvalidMessage, changing nothing.
    function test_primaryBeaconCheck_runsBeforeTheSignature_andChangesNothing() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_ACCEPT);
        m.deliveryHash = rules.deliveryHashOf(id);
        m.beaconRound = 7;
        m.signature = hex"00";
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
        rules.decide(t, _primary(t, id, H.OUTCOME_ACCEPT), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
    }

    /// Fuzz: a signed primary decision settles exactly when all four beacon fields are empty.
    function testFuzz_primaryDecisionSettles_iffEveryBeaconFieldIsEmpty(
        bool setSource,
        uint64 round,
        bytes32 value,
        uint8 sigLen
    ) public {
        sigLen = uint8(bound(sigLen, 0, 96));
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        if (setSource) m.beaconSourceHash = keccak256("sim");
        m.beaconRound = round;
        m.beaconValue = value;
        m.beaconSignature = new bytes(sigLen);
        m = _signDecision(t, id, m, adjudicator, ADJ_PK);
        bool empty = !setSource && round == 0 && value == bytes32(0) && sigLen == 0;
        if (!empty) vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(empty ? IHoldbackRules.Stage.Refunded : IHoldbackRules.Stage.Delivered));
    }

    // ------------------------------------------------------------ helpers

    function _escalatedBy(uint8 role) internal returns (H.Terms memory t, bytes32 id, uint64 at) {
        (t, id) = _funded();
        _deliver(t, id);
        if (role == H.ROLE_PRIMARY) {
            at = uint64(block.timestamp);
            rules.decide(t, _primary(t, id, H.OUTCOME_ESCALATE), _noDelivery(), "");
        } else {
            vm.warp(t.timing.judgeBy);
            rules.triggerFallback(t);
            H.Decision memory fb = _beaconDecision(id, H.ROLE_FALLBACK, H.OUTCOME_ESCALATE, t.timing.judgeBy);
            at = uint64(block.timestamp);
            rules.decide(t, _signDecision(t, id, fb, fallbackAdj, FB_PK), _noDelivery(), "");
        }
        vm.warp(at + 1);
    }
}
