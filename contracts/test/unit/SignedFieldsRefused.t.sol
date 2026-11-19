// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHoldbackRules} from "../../src/IHoldbackRules.sol";
import {HoldbackTypes as H} from "../../src/HoldbackTypes.sol";
import {Base} from "./Base.sol";

/// @title Signed fields that phase one cannot use are refused (T-529, an outside scan's finding, group G4)
/// @notice The state model's register (`docs/audit/state-model.md` §8.3) gives these signed fields the verdict "refuse":
///         the three dispute fields of the terms (optimistic mode only, which phase one does not run), the beacon fields
///         of a primary's decision (the primary proves no beacon round), and the appeal ground of the appeal
///         adjudicator's decision on an escalation (phase one has no party appeal). Each is refused with
///         `InvalidMessage`. Core encodes the terms' dispute fields as 0, and the reference adjudicator signs the other
///         fields empty, so no deal they build is refused. An outside adjudicator that fills one fails only its own
///         decision; the deal's timeout paths stay open.
contract SignedFieldsRefusedTest is Base {
    function _refusesFunding(H.Terms memory t) internal {
        bytes memory s = _sellerSig(t, SELLER_PK);
        H.Acceptance memory a = _acceptance(t, ADJ_PK);
        H.Agree memory g = _agree(t, BUYER_PK);
        H.Funding memory f = _erc3009(t, BUYER_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        vm.prank(relayer);
        rules.agreeAndFund(t, s, a, g, f);
    }

    // ------------------------------------------------------------ the terms' dispute fields

    function test_termsWithDisputeBy_refused() public {
        H.Terms memory t = _terms();
        t.timing.disputeBy = t.timing.fallbackBy + 1;
        _refusesFunding(t);
    }

    function test_termsWithDisputeJudgeSec_refused() public {
        H.Terms memory t = _terms();
        t.timing.disputeJudgeSec = 2;
        _refusesFunding(t);
    }

    function test_termsWithDisputeFallbackSec_refused() public {
        H.Terms memory t = _terms();
        t.timing.disputeFallbackSec = 3;
        _refusesFunding(t);
    }

    function test_termsWithZeroDisputeFields_fund() public {
        (H.Terms memory t, bytes32 id) = _funded();
        assertEq(t.timing.disputeBy + t.timing.disputeJudgeSec + t.timing.disputeFallbackSec, 0);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Held));
    }

    // ------------------------------------------------------------ the primary's beacon fields

    function _refusesPrimary(H.Decision memory m) internal {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        m = _signDecision(t, id, m, adjudicator, ADJ_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
    }

    function test_primaryDecisionWithBeaconSource_refused() public {
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_ACCEPT);
        m.beaconSourceHash = keccak256("drand-quicknet");
        _refusesPrimary(m);
    }

    function test_primaryDecisionWithBeaconRound_refused() public {
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_ACCEPT);
        m.beaconRound = 123;
        _refusesPrimary(m);
    }

    function test_primaryDecisionWithBeaconValue_refused() public {
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        m.beaconValue = keccak256("not a beacon value");
        _refusesPrimary(m);
    }

    function test_primaryDecisionWithBeaconSignature_refused() public {
        H.Decision memory m = _decision(H.ROLE_PRIMARY, H.OUTCOME_ESCALATE);
        m.beaconSignature = hex"deadbeef";
        _refusesPrimary(m);
    }

    function test_primaryDecisionWithEmptyBeaconFields_settles() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        rules.decide(t, _primary(t, id, H.OUTCOME_ACCEPT), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
    }

    // ------------------------------------------------------------ the escalation decision's appeal ground

    function _escalated() internal returns (H.Terms memory t, bytes32 id, uint64 at) {
        (t, id) = _funded();
        _deliver(t, id);
        at = uint64(block.timestamp);
        rules.decide(t, _primary(t, id, H.OUTCOME_ESCALATE), _noDelivery(), "");
        vm.warp(at + 1);
    }

    function test_escalationDecisionWithAppealGround_refused() public {
        (H.Terms memory t, bytes32 id, uint64 at) = _escalated();
        H.Decision memory m = _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_REJECT, at + 1);
        m.appealGroundHash = keccak256("the buyer appealed and won");
        m = _signDecision(t, id, m, appealAdj, AP_PK);
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, m, _noDelivery(), "");
    }

    function test_escalationDecisionWithEmptyAppealGround_settles() public {
        (H.Terms memory t, bytes32 id, uint64 at) = _escalated();
        H.Decision memory m = _beaconDecision(id, H.ROLE_APPEAL, H.OUTCOME_REJECT, at + 1);
        rules.decide(t, _signDecision(t, id, m, appealAdj, AP_PK), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }

    // ------------------------------------------------------------ a late fallback (documented, not refused)

    /// `triggerFallback` has no upper bound in time: sent at or after `fallbackBy`, it opens the fallback's turn with no
    /// time left (a fallback decision is past its deadline), and the default is due at once.
    function test_triggerFallbackAtFallbackBy_leadsStraightToTheDefault() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        vm.warp(t.timing.fallbackBy);
        rules.triggerFallback(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.FallbackJudging));
        H.Decision memory m = _beaconDecision(id, H.ROLE_FALLBACK, H.OUTCOME_ACCEPT, uint64(t.timing.judgeBy));
        m = _signDecision(t, id, m, fallbackAdj, FB_PK);
        vm.expectRevert(IHoldbackRules.DeadlinePassed.selector);
        rules.decide(t, m, _noDelivery(), "");
        rules.triggerDefault(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
    }
}
