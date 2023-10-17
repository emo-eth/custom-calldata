// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Encoder} from "src/Encoder.sol";

contract EncoderTest is Test {
    function testEncodeType1() public {
        bytes32 x = 0x0000;
        bytes memory encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], 0x00);
        x = bytes32(uint256(1));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0x01));
        x = bytes32(uint256(255));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0xff));
        vm.breakpoint("a");
        x = bytes32(uint256(256));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(0x01));
        assertEq(encoded[1], bytes1(0x01));
        assertEq(encoded[2], 0x00);

        x = bytes32(uint256(65535));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(0x01));
        assertEq(encoded[1], bytes1(0xff));
        assertEq(encoded[2], bytes1(0xff));

        x = bytes32(uint256(65536));
        encoded = Encoder.encodeType1(x);

        assertEq(encoded.length, 4);
        assertEq(encoded[0], bytes1(0x02));
        assertEq(encoded[1], bytes1(0x01));
        assertEq(encoded[2], 0x00);
        assertEq(encoded[3], 0x00);

        uint256 y;
        assembly {
            y := not(0)
        }
        x = bytes32(y);
        encoded = Encoder.encodeType1(x);
        emit log_bytes(encoded);
        assertEq(encoded.length, 33);
        assertEq(encoded[0], bytes1(0x1f));
        assertEq(encoded[1], bytes1(0xff));
        assertEq(encoded[32], bytes1(0xff));
    }

    function testEncodeType2() public {
        bytes32 x = bytes32(bytes1(0x00));
        bytes memory encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], 0x00);
    }

    function testMsb() public {
        assertEq(Encoder.msb(0), 0);
        for (uint256 i; i < 256; i++) {
            assertEq(Encoder.msb(1 << i), i);
        }
    }

    function testLsb() public {
        uint256 mask = 1 << 255;
        assertEq(Encoder.lsb(0), 0);
        for (uint256 i; i < 256; i++) {
            assertEq(Encoder.lsb(mask | (1 << i)), i);
        }
    }
}
