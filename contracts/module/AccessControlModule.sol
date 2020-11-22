// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../libraries/Bitwise.sol";
import "../libraries/Constant.sol";

import "../Type.sol";

library AccessControlModule {
    using Bitwise for uint256;

    function grantPrivilege(
        Core storage core,
        address owner,
        address trader,
        uint256 privilege
    ) internal {
        require(_isValid(privilege), "");
        core.accessControls[owner][trader] = core.accessControls[owner][trader]
            .set(privilege);
    }

    function revokePrivilege(
        Core storage core,
        address owner,
        address trader,
        uint256 privilege
    ) internal {
        require(_isValid(privilege), "");
        core.accessControls[owner][trader] = core.accessControls[owner][trader]
            .clean(privilege);
    }

    function isGranted(
        Core storage core,
        address owner,
        address trader,
        uint256 privilege
    ) internal view returns (bool) {
        if (_isValid(privilege)) {
            return false;
        }
        return
            core.accessControls[owner][trader] > 0 &&
            core.accessControls[owner][trader].test(privilege);
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }
}
