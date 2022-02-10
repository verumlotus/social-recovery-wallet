// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "@solmate/tokens/ERC20.sol";
// Adapted from: 
// https://github.com/ZeframLou/vested-erc20/blob/c937b59b14c602cf885b7e144f418a942ee5336b/src/test/mocks/TestERC20.sol

contract MockERC20 is ERC20("MockToken", "MOCK", 18) {
    // Expose external mint function 
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}