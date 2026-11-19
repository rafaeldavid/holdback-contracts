// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHoldbackRules} from "../../src/IHoldbackRules.sol";
import {HoldbackTypes as H} from "../../src/HoldbackTypes.sol";
import {Base} from "../unit/Base.sol";

/// @title A decision that carries the delivery can be made to revert after its seed is public (documenting, group G1)
/// @notice An outside scan's finding, group G1. In Held, the primary's decision may carry the seller's delivery, and
///         its calldata holds the primary's seed. The seller can post another delivery first; the carried decision then
///         reverts, and the seed it published stays the only seed the primary may use, because the deal's seed tag fixes
///         it at funding. The fix is off chain: the operators carry a delivery only in an accept or an early accept. This
///         test documents the contract's behaviour, which the next build keeps; it is not a regression test of a fix.
contract CarriedDeliveryRevertTest is Base {
    function test_carriedDecision_revertsWhenTheSellerDeliversFirst_andItsSeedStaysTheOnlySeed() public {
        (H.Terms memory t, bytes32 id) = _funded();
        (H.Delivery memory first,) = _delivery();
        (H.Delivery memory second,) = _delivery();
        second.ciphertextHash = keccak256("another ciphertext");

        // The primary's reject, carrying the first delivery, with the seed its commitment fixed.
        H.Decision memory carried = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        carried.deliveryHash = hx.delivery(id, first);
        carried = _signDecision(t, id, carried, adjudicator, ADJ_PK);
        bytes memory firstSig = _deliverySig(id, first, SELLER_PK);

        // The seller posts another delivery before the carried decision lands.
        rules.deliver(t, second, _deliverySig(id, second, SELLER_PK));

        // The carried decision reverts; its calldata, with `carried.seed`, was public anyway.
        vm.expectRevert(IHoldbackRules.InvalidMessage.selector);
        rules.decide(t, carried, first, firstSig);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Delivered));

        // A decision on the posted delivery with any other seed is refused: the published seed is the only one.
        H.Decision memory other = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        other.seed = keccak256("another seed");
        other = _signDecision(t, id, other, adjudicator, ADJ_PK);
        vm.expectRevert(IHoldbackRules.BadSeed.selector);
        rules.decide(t, other, _noDelivery(), "");

        // With the published seed (`carried.seed`), the primary decides the second delivery.
        H.Decision memory again = _decision(H.ROLE_PRIMARY, H.OUTCOME_REJECT);
        again.seed = carried.seed;
        rules.decide(t, _signDecision(t, id, again, adjudicator, ADJ_PK), _noDelivery(), "");
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Refunded));
        assertEq(rules.deliveryHashOf(id), hx.delivery(id, second));
    }
}
