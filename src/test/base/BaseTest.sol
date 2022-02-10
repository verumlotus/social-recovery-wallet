// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {DSTest} from "@ds-test/test.sol";
import "../utils/Hevm.sol";
import {console} from "../utils/console.sol";
import {stdCheats, stdStorage, StdStorage} from "@forge-std/stdlib.sol";

contract BaseTest is DSTest, stdCheats {
    using stdStorage for StdStorage;

    StdStorage stdstore;
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
}