// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {MyStruct, MyStructLib} from "src/lib/MyStruct.sol";
import {Encoder} from "src/Encoder.sol";

contract MyStructTest is Test {
    function testEncodeDecode() public {
        MyStruct memory input = MyStruct(1, 2, bytes4(uint32(3)));
        bytes memory encoded = MyStructLib.encode(input);
        encoded = bytes.concat(Encoder.encodeRelativePointer(2), encoded);
        MyStruct memory decoded = this.decode(encoded);
        assertEq(decoded.a, input.a, "invalid a");
        assertEq(decoded.b, input.b, "invalid b");
        assertEq(decoded.c, input.c, "invalid c");
    }

    function testEncodeDecode(MyStruct memory input) public {
        bytes memory encoded = MyStructLib.encode(input);
        encoded = bytes.concat(Encoder.encodeRelativePointer(2), encoded);
        MyStruct memory decoded = this.decode(encoded);
        assertEq(decoded.a, input.a, "invalid a");
        assertEq(decoded.b, input.b, "invalid b");
        assertEq(decoded.c, input.c, "invalid c");
    }

    function testEncodeDecodePacked(MyStruct memory input) public {
        bytes memory encoded = MyStructLib.encode(input);
        MyStruct memory decoded = this.decodePacked(encoded);
        assertEq(decoded.a, input.a, "invalid a");
        assertEq(decoded.b, input.b, "invalid b");
        assertEq(decoded.c, input.c, "invalid c");
    }

    function decode(bytes calldata encoded) external pure returns (MyStruct memory decoded) {
        uint256 offset;
        assembly {
            offset := encoded.offset
        }
        (decoded,) = MyStructLib.decode(offset);
    }

    function decodePacked(bytes calldata encoded) external pure returns (MyStruct memory decoded) {
        uint256 offset;
        assembly {
            offset := encoded.offset
        }
        (decoded,) = MyStructLib.decodePacked(offset);
    }
}
