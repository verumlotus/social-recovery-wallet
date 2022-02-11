// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./base/BaseTest.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";
import "../Wallet.sol";


contract WalletTest is BaseTest {
    MockERC20 mockToken;
    MockERC721 mockNft;
    uint256 tokenId;

    Wallet wallet;
    // homage to 3Blue1Brown
    address owner = address(0x3b1b);
    address newOwner = address(0xdead);

    function _hashAddr(address addr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr));
    }

    // guardians
    address g1 = address(0x1);
    address g2 = address(0x2);
    address g3 = address(0x3);
    bytes32 g1Hash = _hashAddr(g1);
    bytes32 g2Hash = _hashAddr(g2);
    bytes32 g3Hash = _hashAddr(g3);

    address possibleG = address(0x4);
    bytes32 possibleGHash = _hashAddr(possibleG);

    address fakeG;

    function setUp() public {
        // Set up wallet
        bytes32[] memory guardianHashes = new bytes32[](3);
        guardianHashes[0] = g1Hash;
        guardianHashes[1] = g2Hash;
        guardianHashes[2] = g3Hash;
        // spoof owner
        hevm.startPrank(owner);
        wallet = new Wallet(guardianHashes, 2);


        // Set up utils
        mockToken = new MockERC20();
        mockToken.mint(address(wallet), 100*10**mockToken.decimals());
        mockNft = new MockERC721();
        tokenId = 1;
        mockNft.mint(owner, tokenId);
    }

    function testExecuteTx() public {

        uint256 tokensToAdd = 100*10**mockToken.decimals();
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(wallet), tokensToAdd);
        uint256 balanceBefore = mockToken.balanceOf(address(wallet));
        wallet.executeExternalTx(address(mockToken), 0, data);

        // Balance should've increased by 100
        uint256 currBalance = mockToken.balanceOf(address(wallet));
        assertEq(currBalance, balanceBefore + tokensToAdd);
    }

    function testTransfer() public {
        hevm.deal(address(wallet), 10 ether);
        address luckyJoe = address(0xfafa);
        uint256 balanceBefore = luckyJoe.balance;
        wallet.executeExternalTx(luckyJoe, 1 ether, "");

        // Lucky joe got a free one ether
        uint256 balanceAfter = luckyJoe.balance;
        assertEq(balanceAfter, balanceBefore + 1 ether);
    }

    function testInitiateRecovery() public {
        hevm.startPrank(g1);
        wallet.initiateRecovery(newOwner);
    }

    function testRevertInitiateRecovery() public {
        hevm.startPrank(fakeG);
        hevm.expectRevert(bytes("only guardian"));
        wallet.initiateRecovery(newOwner);
    }

    function testSupportRecovery() public {
        testInitiateRecovery();
        hevm.startPrank(g2);
        wallet.supportRecovery(newOwner);
    }

    function testFullRecovery() public {
        testSupportRecovery();
        address[] memory guardianList = new address[](2);
        guardianList[0] = g1;
        guardianList[1] = g2;
        wallet.executeRecovery(newOwner, guardianList);
        assertEq(wallet.owner(), newOwner);
    }

    function testGuardianRemoval() public {
        wallet.initiateGuardianRemoval(g3Hash);
        hevm.warp(block.timestamp + 4 days);
        wallet.executeGuardianRemoval(g3Hash, possibleGHash);

        // Check that g3 is not a guardian, and that possibleG is
        assertTrue(!wallet.isGuardian(g3Hash));
        assertTrue(wallet.isGuardian(possibleGHash));
    }

    function testGuardianNoTransferRemoval() public {
        // ensure that guardian cannot transfer while queued for removal
        wallet.initiateGuardianRemoval(g3Hash);
        hevm.startPrank(g3);
        hevm.expectRevert(bytes("guardian queueud for removal, cannot transfer guardianship"));
        wallet.transferGuardianship(possibleGHash);

    }

    function testERC721Transfer() public {
        mockNft.approve(address(wallet), tokenId);
        mockNft.safeTransferFrom(owner, address(wallet), tokenId);
    }
}
