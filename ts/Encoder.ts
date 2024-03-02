import { numberToBytes } from 'viem';

const bn = BigInt;
const EXPAND_FLAG: bigint = bn(0x20);
const EXPANSION_BIT_CUTOFF: bigint = bn(32);
const ONE_BYTE_BITS: bigint = bn(8);
const BITS_TO_BYTES_SHIFT: bigint = bn(3);
const NOT_FLAG = bn(0x40);
type EncodeComponents = {
    valWidth: bigint;
    metaWidth: bigint;
    meta: bigint;
    y: bigint;
};

function encodeType1(i: bigint): Uint8Array {
    return encodeFromComponents(type1Components(i));
}
function encodeType2(i: bigint): Uint8Array {
    return encodeFromComponents(type2Components(i));
}
function encodeType3(i: bigint): Uint8Array {
    return encodeFromComponents(type3Components(i));
}

function type1Components(i: bigint): EncodeComponents {
    let valWidth = (msb(i) >> bn(3)) + bn(1);
    let metaWidth = bn(1);
    let meta = valWidth - bn(1);
    return { valWidth, metaWidth, meta, y: i };
}
function type2Components(i: bigint): EncodeComponents {
    let expansionBits = lsb(i);
    if (expansionBits < EXPANSION_BIT_CUTOFF) {
        return type1Components(i);
    }
    let newVal = i >> expansionBits;
    let valWidth = (msb(newVal) >> BITS_TO_BYTES_SHIFT) + bn(1);
    let metaWidth = bn(2);
    let meta =
        (((valWidth - bn(1)) | EXPAND_FLAG) << ONE_BYTE_BITS) | expansionBits;
    return { valWidth, metaWidth, meta, y: newVal };
}
function type3Components(i: bigint): EncodeComponents {
    let sign: boolean = i < bn(0);
    let expansionBits = lsb(i);
    let flags: bigint = bn(0);
    expansionBits =
        expansionBits > EXPANSION_BIT_CUTOFF ? bn(0) : expansionBits;
    let newVal = sign
        ? i >> expansionBits
        : BigInt.asUintN(256, i) >> expansionBits;
    newVal = sign ? ~newVal : newVal;
    flags = sign ? EXPAND_FLAG | NOT_FLAG : EXPAND_FLAG;

    let valWidth = (msb(newVal) >> BITS_TO_BYTES_SHIFT) + bn(1);
    let metaWidth = bn(2);
    let meta = (((valWidth - bn(1)) | flags) << ONE_BYTE_BITS) | expansionBits;
    return { valWidth, metaWidth, meta, y: newVal };
}
function encodeFromComponents(components: EncodeComponents): Uint8Array {
    let a = numberToBytes(components.meta, {
        size: Number(components.metaWidth),
    });
    let b = numberToBytes(components.y, { size: Number(components.valWidth) });
    return appendBuffer(a, b);
}

var appendBuffer = function (buffer1: Uint8Array, buffer2: Uint8Array) {
    var tmp = new Uint8Array(buffer1.byteLength + buffer2.byteLength);
    tmp.set(buffer1, 0);
    tmp.set(buffer2, buffer1.byteLength);
    return Uint8Array.from(tmp);
};

function msb(bigIntValue: bigint): bigint {
    if (bigIntValue === bn(0)) {
        return bn(0);
    }

    let count = bn(0);
    while (bigIntValue > bn(1)) {
        bigIntValue = bigIntValue / bn(2);
        count++;
    }

    return count;
}

function lsb(n: bigint): bigint {
    n = BigInt.asUintN(256, n);
    return msb(n & -n);
}
