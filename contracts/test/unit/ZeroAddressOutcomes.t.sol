// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHoldbackRules} from "../../src/IHoldbackRules.sol";
import {HoldbackTypes as H} from "../../src/HoldbackTypes.sol";
import {Base} from "./Base.sol";

/// @title What a zero address in the terms does (documenting; RR-3, T-529)
/// @notice The contract compares neither money address with anything, the zero address included (ADR-0033 §2, D31):
///         the operators warn, and the parties may still choose it. These tests pin what two such choices do, so the
///         stated outcomes are measured. No refusal is added.
contract ZeroAddressOutcomesTest is Base {
    /// A zero payout address funds. On a token that allows a transfer to the zero address (Solady's ERC-20, under both
    /// this mock and the demo's TestUSDC), an accept settles and the price goes to the zero address: the seller's own
    /// choice loses the seller's payment. The decider still gets its fee.
    function test_zeroPayoutAddress_funds_andAnAcceptSendsThePriceToTheZeroAddress() public {
        H.Terms memory t = _terms();
        t.sellerPayoutAddress = address(0);
        bytes32 id = _fund(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Held));
        _deliver(t, id);
        uint256 burnedBefore = usdc.balanceOf(address(0));
        uint256 feeBefore = usdc.balanceOf(adjudicator);
        rules.decide(t, _primary(t, id, H.OUTCOME_ACCEPT), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Released));
        assertEq(usdc.balanceOf(address(0)) - burnedBefore, PRICE, "the price went to the zero address");
        assertEq(usdc.balanceOf(adjudicator) - feeBefore, FEE, "the primary got its fee");
    }

    /// A zero fallback adjudicator funds. No signature verifies for the zero address, so the fallback's turn can only
    /// end in the default: price + fee back to the buyer's payment address.
    function test_zeroFallbackAdjudicator_funds_andTheFallbackPathEndsInTheDefaultRefund() public {
        H.Terms memory t = _terms();
        t.fallbackAdjudicator = address(0);
        bytes32 id = _fund(t);
        _deliver(t, id);
        vm.warp(t.timing.judgeBy);
        rules.triggerFallback(t);
        H.Decision memory m = _beaconDecision(id, H.ROLE_FALLBACK, H.OUTCOME_ACCEPT, uint64(t.timing.judgeBy));
        m = _signDecision(t, id, m, address(0), FB_PK);
        vm.expectRevert(IHoldbackRules.BadSignature.selector);
        rules.decide(t, m, _noDelivery(), "");
        vm.warp(t.timing.fallbackBy);
        uint256 before = usdc.balanceOf(t.buyerPaymentAddress);
        rules.triggerDefault(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
        assertEq(usdc.balanceOf(t.buyerPaymentAddress) - before, PRICE + FEE, "the whole hold went back to the buyer");
    }
}
