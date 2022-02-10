// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import "@solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721("MockNft", "") {
    string baseURI = "yeet";
    // Expose external mint function 
    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return baseURI;
    }
}