// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {HoldbackRules} from "../../src/HoldbackRules.sol";
import {IHoldbackRules} from "../../src/IHoldbackRules.sol";
import {IHoldbackBeacon} from "../../src/IHoldbackBeacon.sol";
import {DrandQuicknetBeacon} from "../../src/DrandQuicknetBeacon.sol";
import {HoldbackTypes as H} from "../../src/HoldbackTypes.sol";
import {Base} from "./Base.sol";

/// @dev A beacon whose `roundAt` reverts.
contract RevertingBeacon is IHoldbackBeacon {
    function roundAt(uint256) external pure returns (uint64) {
        revert("no rounds");
    }

    function beaconValue(uint64, bytes calldata) external pure returns (bytes32) {
        revert("no rounds");
    }
}

/// @dev A beacon whose `roundAt` answers 31 bytes.
contract ShortBeacon {
    fallback() external {
        assembly {
            return(0, 31)
        }
    }
}

/// @title The constructor asks the beacon for one round (T-527, an outside scan's finding, group G2)
/// @notice `triggerFallback` asks the beacon for a round, and it is the only timeout exit from Delivered. A beacon that
///         cannot answer `roundAt` would make that exit revert for the deployment's life, so the constructor asks once
///         and refuses with `BadBeacon` when the address has no code, the call reverts or it returns short data. The
///         other three addresses get no code check (Rafa, 2026-11-12 and 2026-11-18; T-380): the deploy script checks
///         them.
contract BeaconProbeTest is Base {
    function deploy(IHoldbackBeacon b) external returns (address) {
        return address(new HoldbackRules(escrow, address(collector3009), MARGIN, b, address(usdc), 0));
    }

    function _deploy(IHoldbackBeacon b) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(this).call(abi.encodeCall(this.deploy, (b)));
    }

    function test_beaconWithoutCode_refused() public {
        (bool ok, bytes memory ret) = _deploy(IHoldbackBeacon(address(0xBEAC0)));
        assertFalse(ok, "a beacon with no code deploys");
        assertEq(ret, abi.encodeWithSelector(IHoldbackRules.BadBeacon.selector));
    }

    function test_beaconThatReverts_refused() public {
        (bool ok, bytes memory ret) = _deploy(new RevertingBeacon());
        assertFalse(ok, "a beacon whose roundAt reverts deploys");
        assertEq(ret, abi.encodeWithSelector(IHoldbackRules.BadBeacon.selector));
    }

    function test_simBeacon_deploys() public {
        (bool ok,) = _deploy(sim);
        assertTrue(ok);
    }

    function test_drandBeacon_deploys() public {
        (bool ok,) = _deploy(new DrandQuicknetBeacon(250_000));
        assertTrue(ok);
    }

    function test_beaconWithShortAnswer_refused() public {
        (bool ok, bytes memory ret) = _deploy(IHoldbackBeacon(address(new ShortBeacon())));
        assertFalse(ok, "a beacon whose roundAt returns 31 bytes deploys");
        assertEq(ret, abi.encodeWithSelector(IHoldbackRules.BadBeacon.selector));
    }

    /// What the probe prevents, shown by taking the beacon's code away after the deploy: a delivered deal whose primary
    /// stays silent cannot reach the fallback, and the default needs the fallback's stage, so no timeout moves it. It
    /// waits for the buyer's early accept, a settlement both parties sign, or the escrow's expiry, when the buyer's
    /// payment address may reclaim the hold on the escrow directly. A demonstration of the finding, not a regression
    /// test: it holds with or without the probe.
    function test_beaconWithoutCode_leavesADeliveredDealNoTimeoutExit() public {
        (H.Terms memory t, bytes32 id) = _funded();
        _deliver(t, id);
        vm.warp(t.timing.judgeBy);
        vm.etch(address(sim), "");
        vm.expectRevert(bytes(""));
        rules.triggerFallback(t);
        vm.expectRevert(abi.encodeWithSelector(IHoldbackRules.WrongStage.selector, IHoldbackRules.Stage.Delivered));
        rules.triggerDefault(t);
        vm.warp(t.timing.fallbackBy + t.timing.appealDecideSec);
        vm.expectRevert(bytes(""));
        rules.triggerFallback(t);
        assertEq(uint8(_stage(id)), uint8(IHoldbackRules.Stage.Delivered));
    }
}
