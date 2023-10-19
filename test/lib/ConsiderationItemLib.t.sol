// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {ConsiderationItemLib} from "src/lib/ConsiderationItemLib.sol";
import {ConsiderationItem} from "seaport-types/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/lib/ConsiderationEnums.sol";
import {Parser} from "src/Parser.sol";
import {Encoder} from "src/Encoder.sol";
import {LibZip} from "solady/utils/LibZip.sol";

contract ConsiderationItemLibTest is Test {
    struct FuzzConsiderationItem {
        uint8 itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }

    function testEncodeDecode() public {
        ConsiderationItem memory input = ConsiderationItem({
            itemType: ItemType.ERC1155,
            token: address(1),
            identifierOrCriteria: 2,
            startAmount: 3,
            endAmount: 4,
            recipient: payable(address(5))
        });
        bytes memory encoded = ConsiderationItemLib.encode(input);
        encoded = bytes.concat(Encoder.encodeRelativePointer(2), encoded);
        ConsiderationItem memory decoded = this.decode(encoded);
        assertEq(uint8(decoded.itemType), uint8(input.itemType), "invalid itemType");
        assertEq(decoded.token, input.token, "invalid token");
        assertEq(decoded.identifierOrCriteria, input.identifierOrCriteria, "invalid identifierOrCriteria");
        assertEq(decoded.startAmount, input.startAmount, "invalid startAmount");
        assertEq(decoded.endAmount, input.endAmount, "invalid endAmount");
        assertEq(decoded.recipient, input.recipient, "invalid recipient");
    }

    function testEncodeDecode(FuzzConsiderationItem memory _input) public {
        ConsiderationItem memory input = cast(_input);

        bytes memory encoded = ConsiderationItemLib.encode((input));
        encoded = bytes.concat(Encoder.encodeRelativePointer(2), encoded);
        ConsiderationItem memory decoded = this.decode(encoded);
        assertEq(uint8(decoded.itemType), uint8(input.itemType), "invalid itemType");
        assertEq(decoded.token, input.token, "invalid token");
        assertEq(decoded.identifierOrCriteria, input.identifierOrCriteria, "invalid identifierOrCriteria");
        assertEq(decoded.startAmount, input.startAmount, "invalid startAmount");
        assertEq(decoded.endAmount, input.endAmount, "invalid endAmount");
        assertEq(decoded.recipient, input.recipient, "invalid recipient");
    }

    function testEncodeDecodePacked(FuzzConsiderationItem memory _input) public {
        ConsiderationItem memory input = cast(_input);
        bytes memory encoded = ConsiderationItemLib.encode((input));
        ConsiderationItem memory decoded = this.decodePacked(encoded);
        assertEq(uint8(decoded.itemType), uint8(input.itemType), "invalid itemType");
        assertEq(decoded.token, input.token, "invalid token");
        assertEq(decoded.identifierOrCriteria, input.identifierOrCriteria, "invalid identifierOrCriteria");
        assertEq(decoded.startAmount, input.startAmount, "invalid startAmount");
        assertEq(decoded.endAmount, input.endAmount, "invalid endAmount");
        assertEq(decoded.recipient, input.recipient, "invalid recipient");
    }

    function calcCost(bytes memory arr) internal pure returns (uint256 sum) {
        for (uint256 i; i < arr.length; i++) {
            sum += (arr[i] == 0) ? 4 : 16;
        }
    }

    function testCompare() public {
        ConsiderationItem memory input = ConsiderationItem({
            itemType: ItemType.ERC1155,
            token: address(this),
            identifierOrCriteria: 0,
            startAmount: 1e18,
            endAmount: 2e18,
            recipient: payable(address(this))
        });
        benchmark(input);
        input = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(this),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(this))
        });
        benchmark(input);
        // fail();
    }

    function benchmark(ConsiderationItem memory input) internal {
        bytes memory encoded = ConsiderationItemLib.encode(input);
        emit log_named_bytes("custom", encoded);
        emit log_named_uint("custom cost", calcCost(encoded));
        bytes memory abiEncoded = abi.encode(input);
        emit log_named_bytes("abi", abiEncoded);
        emit log_named_uint("abi cost", calcCost(abiEncoded));
        bytes memory zipped = LibZip.flzCompress(encoded);
        emit log_named_bytes("flz custom ", zipped);
        emit log_named_uint("flz custom cost", calcCost(zipped));
        bytes memory cd = LibZip.cdCompress(encoded);
        emit log_named_bytes("cd custom", cd);
        emit log_named_uint("cd custom cost", calcCost(cd));
        zipped = LibZip.flzCompress(abiEncoded);
        emit log_named_bytes("flz abi", zipped);
        emit log_named_uint("flz abi cost", calcCost(zipped));
        cd = LibZip.cdCompress(abiEncoded);
        emit log_named_bytes("cd abi", cd);
        emit log_named_uint("cd abi cost", calcCost(cd));

        assertEq(LibZip.flzDecompress(LibZip.flzCompress(encoded)), encoded, "flz decompress");
    }

    function testBenchmarkDecompressDecode() public {
        bytes memory data = hex"1c0002137fa9385be102ac3eac297483dd6233d62b3e1496000000010001e0071a04d62b3e1496";

        bytes memory decompressed = LibZip.flzDecompress(data);
        ConsiderationItem memory decoded = this.decodePacked(decompressed);
    }

    function testBenchmarkDecode() public {
        bytes memory data =
            hex"0002137fa9385be102ac3eac297483dd6233d62b3e1496000000010001137fa9385be102ac3eac297483dd6233d62b3e1496";
        ConsiderationItem memory decoded = this.decodePacked(data);
    }

    function cast(FuzzConsiderationItem memory item) internal returns (ConsiderationItem memory casted) {
        casted.itemType = ItemType(uint8(bound(item.itemType, 0, 5)));
        casted.token = item.token;
        casted.identifierOrCriteria = item.identifierOrCriteria;
        casted.startAmount = item.startAmount;
        casted.endAmount = item.endAmount;
        casted.recipient = item.recipient;
    }

    function decode(bytes calldata encoded) external pure returns (ConsiderationItem memory decoded) {
        uint256 offset;
        assembly {
            offset := encoded.offset
        }
        (decoded,) = ConsiderationItemLib.decodeFromPointer(offset);
    }

    function decodePacked(bytes calldata encoded) external pure returns (ConsiderationItem memory decoded) {
        uint256 offset;
        assembly {
            offset := encoded.offset
        }
        (decoded,) = ConsiderationItemLib.decode(offset);
    }
}
