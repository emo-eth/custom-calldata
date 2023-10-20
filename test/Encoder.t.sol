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

        x = bytes32(bytes1(0x01));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(248)));
        assertEq(encoded[2], bytes1(0x01));

        x = bytes32(bytes2(0x00ff));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(240)));
        assertEq(encoded[2], bytes1(0xff));
        x = bytes32(uint256(1));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0x01));
        x = bytes32(uint256(1 << 255) - 1);
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 33);
        assertEq(encoded[0], bytes1(uint8(0x1f)));
        assertEq(encoded[1], bytes1(0x7f));
        assertEq(encoded[32], bytes1(0xff));

        x = bytes32(bytes4(0x000001c0));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(230)));
        assertEq(encoded[2], bytes1(0x07));
    }

    function testEncodeType2SpanningBits() public {
        uint256 x;
        for (uint256 i = 4; i < 31; i++) {
            uint256 bits = i * 8;
            uint256 shift = bits + 7;
            x = 3 << shift;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 3);
            assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
            assertEq(encoded[1], bytes1(uint8(shift)));
            assertEq(encoded[2], bytes1(0x03));
        }
    }

    function testEncodeType3() public {
        int256 x = -1;
        bytes memory encoded = Encoder.encodeType3(int256(x));
        emit log_bytes(encoded);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.SIGNED_FLAG)));
        assertEq(encoded[1], bytes1(0x00));
        assertEq(encoded[2], bytes1(0x00));
    }

    function testEncodePackingBits() public {
        uint256 x;
        for (uint256 i = 0; i < Encoder.EXPANSION_BIT_CUTOFF; i++) {
            x = 1 << i;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 2 + (i / 8), "bad length");
            assertEq(encoded[0], bytes1(uint8(i / 8)), "bad meta");
            assertEq(encoded[1], bytes1(uint8(1 << (i % 8))), "bad value");
        }
        for (uint256 i = Encoder.EXPANSION_BIT_CUTOFF; i < 256; i++) {
            x = 1 << i;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 3, "bad length");
            assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)), "bad meta");
            assertEq(encoded[1], bytes1(uint8(i)), "bad expand");
            assertEq(encoded[2], bytes1(0x01), "bad val");
        }
    }

    function testReadme() public {
        bytes32 value;
        bytes memory type2;
        value = 0x0000000000000000000000000000000000000000000000000000000000000000; // 32 zero-bytes
        type2 = hex"0000"; // 2 zero-bytes
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x0000000000000000000000000000000000000000000000000000000000000001; // 31 zero-bytes, 1 non-zero byte
        type2 = hex"0001"; // 1 zero-byte,   1 non-zero byte
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x0000000000000000000000000000000000000000000000000000000000000100; // 31 zero-bytes, 1 non-zero byte
        type2 = hex"010100"; // 1 zero-byte,   1 non-zero byte
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x0100000000000000000000000000000000000000000000000000000000000000; // 31 zero-bytes, 1 non-zero byte
        type2 = hex"20f801"; // 0 zero-bytes,  3 non-zero bytes
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x0000000000000000000000000000000000000000000000000000001000000000; // 31 zero-bytes, 1 non-zero byte
        type2 = hex"202401"; // 0 zero-bytes,  3 non-zero bytes
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x000000000000000000000000000000000000000000000000000001c000000000; // 30 zero-bytes, 2 non-zero bytes
        type2 = hex"202607";
        assertEq(Encoder.encodeType2(value), type2);
        value = 0x0000000000000000000000000000000000000000000000000001c11000000000;
        type2 = hex"21241c11";
        assertEq(Encoder.encodeType2(value), type2);
    }

    function testEncodeArrayLiteralBytes() public {
        bytes memory input = hex"000102030405060708090a0b0c0d0e0f";
        bytes memory encoded = Encoder.encodeArrayLiteralBytes(input);
        assertEq(encoded.length, 2 + input.length);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.ARRAY_FLAG)));
        assertEq(encoded[1], bytes1(uint8(input.length)));
        for (uint256 i; i < input.length; i++) {
            assertEq(encoded[i + 2], input[i]);
        }
    }

    function testEncodeArrayLiteralWords() public {
        bytes32[] memory input = new bytes32[](3);
        input[0] = bytes32(bytes1(0x01));
        input[1] = bytes32(bytes1(0x02));
        input[2] = bytes32(bytes1(0x03));
        bytes memory encoded = Encoder.encodeArrayLiteralWords(input);
        assertEq(encoded.length, 2 + input.length * 32);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.ARRAY_FLAG | Encoder.ARRAY_WORD_ELEMENTS_FLAG)));
        assertEq(encoded[1], bytes1(uint8(input.length)));
        for (uint256 i; i < input.length; i++) {
            assertEq(encoded[i * 32 + 2], input[i][0]);
        }
    }

    function testEncodeArrayCompact() public {
        bytes32[] memory input = new bytes32[](3);
        input[0] = bytes32(bytes1(0x01));
        input[1] = bytes32(bytes1(0x03));
        input[2] = bytes32(bytes1(0x05));
        bytes memory encoded = Encoder.encodeArrayCompact(input);
        assertEq(encoded.length, 2 + input.length * 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.ARRAY_FLAG)), "bad array meta");
        assertEq(encoded[1], bytes1(uint8(input.length)), "bad array length");
        for (uint256 i; i < input.length; i++) {
            assertEq(encoded[i * 3 + 2], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)), "bad meta");
            assertEq(encoded[i * 3 + 3], bytes1(uint8(248)), "bad expand");
            assertEq(encoded[i * 3 + 4], input[i][0], "bad value");
        }
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
