// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeableProxy is TransparentUpgradeableProxy {
    constructor(address implementation_, address admin_, bytes memory initData_)
        payable
        TransparentUpgradeableProxy(implementation_, admin_, initData_)
    {}

    function admin() public view returns (address) {
        return _proxyAdmin();
    }

    function implementation() public view returns (address) {
        return _implementation();
    }
}
