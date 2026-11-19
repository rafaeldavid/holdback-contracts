// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DrandQuicknetBeacon} from "../../src/DrandQuicknetBeacon.sol";

/// @title The beacon's pairing gas is a constructor value with a floor (T-528, an outside scan's finding, group G3)
/// @notice The gas the beacon forwards to PAIRING_CHECK is fixed at deploy, at or above two pairs' price under
///         EIP-2537 (102,900 gas), so a repricing is met by deploying a beacon with a higher value instead of
///         failing every proof. A proof that reaches the pairing with too little gas reverts `NotEnoughGas`, so a
///         relayer can tell it from a proof that does not verify (`InvalidSignature`). The beacons are deployed from
///         their creation code with the value appended, so the tests compile against the beacon before and after.
contract BeaconPairingGasTest is Test {
    bytes internal constant SIG_1000 =
        hex"b44679b9a59af2ec876b1a6b1ad52ea9b1615fc3982b19576350f93447cb1125e342b73a8dd2bacbe47e4b6b63ed5e39";
    bytes32 internal constant RAND_1000 = 0xfe290beca10872ef2fb164d2aa4442de4566183ec51c56ff3cd603d930e54fdd;
    uint256 internal constant FLOOR = 102_900;

    function _create(uint256 pairingGas) internal returns (address b) {
        bytes memory init = abi.encodePacked(vm.getCode("DrandQuicknetBeacon.sol:DrandQuicknetBeacon"), abi.encode(pairingGas));
        assembly {
            b := create(0, add(init, 0x20), mload(init))
        }
    }

    function test_pairingGasBelowTheFloor_refused() public {
        assertEq(_create(FLOOR - 1), address(0), "a beacon with less than two pairs' price deploys");
    }

    function test_pairingGasAtTheFloor_verifiesARealRound() public {
        address b = _create(FLOOR);
        assertTrue(b != address(0), "a beacon at the floor does not deploy");
        assertEq(DrandQuicknetBeacon(b).beaconValue(1000, SIG_1000), RAND_1000);
    }

    function test_pairingGas_isTheConstructorValue() public {
        address b = _create(400_000);
        (bool ok, bytes memory ret) = b.staticcall(abi.encodeWithSignature("PAIRING_GAS()"));
        assertTrue(ok, "the beacon does not state its pairing gas");
        assertEq(abi.decode(ret, (uint256)), 400_000);
    }

    /// A valid proof sent with any gas from 1 either verifies, reverts `NotEnoughGas`, or runs out of gas with too little
    /// left to revert with data (an empty revert); it never reverts `InvalidSignature`. Steps of 1 gas up to 40,000
    /// cover the precompile calls before the pairing; steps of 1,000 above cover the pairing.
    function test_validProofWithTooLittleGas_neverRevertsInvalidSignature() public {
        address b = _create(250_000);
        bytes memory call = abi.encodeCall(DrandQuicknetBeacon.beaconValue, (1000, SIG_1000));
        uint256 short;
        uint256 verified;
        for (uint256 g = 1; g <= 420_000; g += g < 40_000 ? 1 : 1_000) {
            (bool ok, bytes memory ret) = b.staticcall{gas: g}(call);
            if (ok) {
                assertEq(abi.decode(ret, (bytes32)), RAND_1000);
                verified++;
            } else if (ret.length == 0) {
                continue;
            } else {
                assertEq(ret, abi.encodeWithSelector(DrandQuicknetBeacon.NotEnoughGas.selector), vm.toString(g));
                short++;
            }
        }
        assertGt(short, 0, "no gas in the range reached the pairing short");
        assertGt(verified, 0, "no gas in the range verified the proof");
    }

    /// A proof that does not verify still reverts `InvalidSignature` when the pairing gets its full gas.
    function test_wrongRoundWithEnoughGas_revertsInvalidSignature() public {
        address b = _create(250_000);
        vm.expectRevert(DrandQuicknetBeacon.InvalidSignature.selector);
        DrandQuicknetBeacon(b).beaconValue{gas: 1_000_000}(1001, SIG_1000);
    }
}
