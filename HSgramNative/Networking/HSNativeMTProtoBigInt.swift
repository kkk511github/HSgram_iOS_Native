import Foundation

enum HSNativeMTProtoBigIntError: LocalizedError {
    case invalidModulus

    var errorDescription: String? {
        switch self {
        case .invalidModulus:
            return "MTProto DH modulus must be a non-zero odd integer."
        }
    }
}

enum HSNativeMTProtoBigInt {
    static func modExp(base: Data, exponent: Data, modulus: Data, outputLength: Int? = nil) throws -> Data {
        let context = try MontgomeryContext(modulus: modulus)
        let baseValue = context.reducedValue(from: base)
        let baseMontgomery = context.toMontgomery(baseValue)
        var result = context.toMontgomery(context.one)

        for byte in exponent {
            for bit in stride(from: 7, through: 0, by: -1) {
                result = context.montgomeryMultiply(result, result)
                if (byte & UInt8(1 << bit)) != 0 {
                    result = context.montgomeryMultiply(result, baseMontgomery)
                }
            }
        }

        let normal = context.fromMontgomery(result)
        return context.bigEndianData(from: normal, exactLength: outputLength)
    }

    static func modMultiply(_ lhs: Data, _ rhs: Data, modulus: Data, outputLength: Int? = nil) throws -> Data {
        let context = try MontgomeryContext(modulus: modulus)
        let left = context.toMontgomery(context.reducedValue(from: lhs))
        let right = context.toMontgomery(context.reducedValue(from: rhs))
        let product = context.fromMontgomery(context.montgomeryMultiply(left, right))
        return context.bigEndianData(from: product, exactLength: outputLength)
    }

    static func modSubtract(_ lhs: Data, _ rhs: Data, modulus: Data, outputLength: Int? = nil) throws -> Data {
        let context = try MontgomeryContext(modulus: modulus)
        let result = context.subtractModulo(context.reducedValue(from: lhs), context.reducedValue(from: rhs))
        return context.bigEndianData(from: result, exactLength: outputLength)
    }

    static func add(_ lhs: Data, _ rhs: Data) -> Data {
        let left = limbs(fromBigEndian: lhs)
        let right = limbs(fromBigEndian: rhs)
        let count = max(left.count, right.count)
        var result = [UInt32](repeating: 0, count: count + 1)
        var carry: UInt64 = 0
        for index in 0..<count {
            let sum = UInt64(index < left.count ? left[index] : 0)
                + UInt64(index < right.count ? right[index] : 0)
                + carry
            result[index] = UInt32(truncatingIfNeeded: sum)
            carry = sum >> 32
        }
        result[count] = UInt32(truncatingIfNeeded: carry)
        return bigEndianData(from: result)
    }

    static func multiply(_ lhs: Data, _ rhs: Data) -> Data {
        let left = limbs(fromBigEndian: lhs)
        let right = limbs(fromBigEndian: rhs)
        guard !(left.count == 1 && left[0] == 0), !(right.count == 1 && right[0] == 0) else {
            return Data([0])
        }
        var result = [UInt32](repeating: 0, count: left.count + right.count)
        for i in 0..<left.count {
            var carry: UInt64 = 0
            for j in 0..<right.count {
                let index = i + j
                let product = UInt64(left[i]) * UInt64(right[j]) + UInt64(result[index]) + carry
                result[index] = UInt32(truncatingIfNeeded: product)
                carry = product >> 32
            }
            var index = i + right.count
            while carry != 0 {
                if index == result.count {
                    result.append(0)
                }
                let sum = UInt64(result[index]) + carry
                result[index] = UInt32(truncatingIfNeeded: sum)
                carry = sum >> 32
                index += 1
            }
        }
        return bigEndianData(from: result)
    }

    private static func limbs(fromBigEndian data: Data) -> [UInt32] {
        var limbs = [UInt32](repeating: 0, count: max(1, (data.count + 3) / 4))
        for (byteIndex, byte) in data.reversed().enumerated() {
            limbs[byteIndex / 4] |= UInt32(byte) << UInt32((byteIndex % 4) * 8)
        }
        return limbs
    }

    private static func bigEndianData(from limbs: [UInt32]) -> Data {
        var bytes: [UInt8] = []
        var hasSeenNonZero = false
        for limb in limbs.reversed() {
            for shift in stride(from: 24, through: 0, by: -8) {
                let byte = UInt8((limb >> UInt32(shift)) & 0xff)
                if byte != 0 || hasSeenNonZero {
                    bytes.append(byte)
                    hasSeenNonZero = true
                }
            }
        }
        return hasSeenNonZero ? Data(bytes) : Data([0])
    }
}

private struct MontgomeryContext {
    private static let wordMask: UInt64 = 0xffff_ffff
    private static let wordBase: UInt64 = 0x1_0000_0000

    let modulus: [UInt32]
    let n: Int
    let mPrime: UInt32
    let one: [UInt32]
    private let r2: [UInt32]

    init(modulus modulusData: Data) throws {
        var bytes = Array(modulusData)
        while bytes.first == 0 {
            bytes.removeFirst()
        }
        guard !bytes.isEmpty, (bytes.last! & 1) == 1 else {
            throw HSNativeMTProtoBigIntError.invalidModulus
        }

        self.n = max(1, (bytes.count + 3) / 4)
        self.modulus = Self.limbs(fromBigEndian: Data(bytes), count: self.n)
        self.mPrime = 0 &- Self.inverseModuloWord(self.modulus[0])

        var oneValue = [UInt32](repeating: 0, count: self.n)
        oneValue[0] = 1
        self.one = oneValue

        var r2Value = oneValue
        for _ in 0..<(self.n * 64) {
            Self.leftShiftOneModulo(&r2Value, modulus: self.modulus)
        }
        self.r2 = r2Value
    }

    func reducedValue(from data: Data) -> [UInt32] {
        var value = [UInt32](repeating: 0, count: n)
        for byte in data {
            for bit in stride(from: 7, through: 0, by: -1) {
                Self.leftShiftOneModulo(&value, modulus: modulus)
                if (byte & UInt8(1 << bit)) != 0 {
                    Self.addOneModulo(&value, modulus: modulus)
                }
            }
        }
        return value
    }

    func toMontgomery(_ value: [UInt32]) -> [UInt32] {
        montgomeryMultiply(value, r2)
    }

    func fromMontgomery(_ value: [UInt32]) -> [UInt32] {
        montgomeryMultiply(value, one)
    }

    func montgomeryMultiply(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        precondition(lhs.count == n && rhs.count == n)

        var t = [UInt32](repeating: 0, count: n + 2)
        for i in 0..<n {
            var carry: UInt64 = 0
            for j in 0..<n {
                let product = UInt64(lhs[j]) * UInt64(rhs[i]) + UInt64(t[j]) + carry
                t[j] = UInt32(truncatingIfNeeded: product)
                carry = product >> 32
            }
            Self.addCarry(carry, to: &t, at: n)

            let u = UInt32(truncatingIfNeeded: UInt64(t[0]) * UInt64(mPrime))
            carry = 0
            for j in 0..<n {
                let product = UInt64(u) * UInt64(modulus[j]) + UInt64(t[j]) + carry
                t[j] = UInt32(truncatingIfNeeded: product)
                carry = product >> 32
            }
            Self.addCarry(carry, to: &t, at: n)

            for j in 0..<(n + 1) {
                t[j] = t[j + 1]
            }
            t[n + 1] = 0
        }

        var result = Array(t[0..<n])
        var high = t[n]
        while high != 0 || Self.compare(result, modulus) >= 0 {
            let borrow = Self.subtractModulus(from: &result, modulus)
            if borrow != 0 {
                high &-= 1
            }
        }
        return result
    }

    func subtractModulo(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        precondition(lhs.count == n && rhs.count == n)
        var result = lhs
        let borrow = Self.subtract(rhs, from: &result)
        if borrow != 0 {
            Self.add(modulus, to: &result)
        }
        return result
    }

    func bigEndianData(from limbs: [UInt32], exactLength: Int? = nil) -> Data {
        var bytes: [UInt8] = []
        var hasSeenNonZero = false
        for limb in limbs.reversed() {
            for shift in stride(from: 24, through: 0, by: -8) {
                let byte = UInt8((limb >> UInt32(shift)) & 0xff)
                if byte != 0 || hasSeenNonZero {
                    bytes.append(byte)
                    hasSeenNonZero = true
                }
            }
        }

        let minimal = hasSeenNonZero ? Data(bytes) : Data([0])
        guard let exactLength else {
            return minimal
        }
        if minimal.count == 1, minimal.first == 0 {
            return Data(repeating: 0, count: exactLength)
        }
        if minimal.count == exactLength {
            return minimal
        }
        precondition(minimal.count < exactLength)
        return Data(repeating: 0, count: exactLength - minimal.count) + minimal
    }

    private static func limbs(fromBigEndian data: Data, count: Int) -> [UInt32] {
        var limbs = [UInt32](repeating: 0, count: count)
        for (byteIndex, byte) in data.reversed().enumerated() {
            let limbIndex = byteIndex / 4
            guard limbIndex < count else {
                break
            }
            limbs[limbIndex] |= UInt32(byte) << UInt32((byteIndex % 4) * 8)
        }
        return limbs
    }

    private static func inverseModuloWord(_ value: UInt32) -> UInt32 {
        var inverse: UInt32 = 1
        for _ in 0..<5 {
            inverse = inverse &* (2 &- value &* inverse)
        }
        return inverse
    }

    private static func leftShiftOneModulo(_ value: inout [UInt32], modulus: [UInt32]) {
        var carry: UInt32 = 0
        for index in 0..<value.count {
            let nextCarry = value[index] >> 31
            value[index] = (value[index] << 1) | carry
            carry = nextCarry
        }
        if carry != 0 || compare(value, modulus) >= 0 {
            _ = subtractModulus(from: &value, modulus)
        }
    }

    private static func addOneModulo(_ value: inout [UInt32], modulus: [UInt32]) {
        var carry: UInt64 = 1
        var index = 0
        while carry != 0, index < value.count {
            let sum = UInt64(value[index]) + carry
            value[index] = UInt32(truncatingIfNeeded: sum)
            carry = sum >> 32
            index += 1
        }
        if carry != 0 || compare(value, modulus) >= 0 {
            _ = subtractModulus(from: &value, modulus)
        }
    }

    private static func compare(_ lhs: [UInt32], _ rhs: [UInt32]) -> Int {
        precondition(lhs.count == rhs.count)
        for index in stride(from: lhs.count - 1, through: 0, by: -1) {
            if lhs[index] < rhs[index] {
                return -1
            }
            if lhs[index] > rhs[index] {
                return 1
            }
        }
        return 0
    }

    private static func subtractModulus(from value: inout [UInt32], _ modulus: [UInt32]) -> UInt32 {
        subtract(modulus, from: &value)
    }

    private static func subtract(_ rhs: [UInt32], from value: inout [UInt32]) -> UInt32 {
        precondition(value.count == rhs.count)
        var borrow: UInt64 = 0
        for index in 0..<value.count {
            let minuend = UInt64(value[index])
            let subtrahend = UInt64(rhs[index]) + borrow
            if minuend >= subtrahend {
                value[index] = UInt32(truncatingIfNeeded: minuend - subtrahend)
                borrow = 0
            } else {
                value[index] = UInt32(truncatingIfNeeded: Self.wordBase + minuend - subtrahend)
                borrow = 1
            }
        }
        return UInt32(borrow)
    }

    private static func add(_ rhs: [UInt32], to value: inout [UInt32]) {
        precondition(value.count == rhs.count)
        var carry: UInt64 = 0
        for index in 0..<value.count {
            let sum = UInt64(value[index]) + UInt64(rhs[index]) + carry
            value[index] = UInt32(truncatingIfNeeded: sum)
            carry = sum >> 32
        }
    }

    private static func addCarry(_ carry: UInt64, to value: inout [UInt32], at startIndex: Int) {
        var carry = carry
        var index = startIndex
        while carry != 0 {
            precondition(index < value.count)
            let sum = UInt64(value[index]) + (carry & wordMask)
            value[index] = UInt32(truncatingIfNeeded: sum)
            carry = (carry >> 32) + (sum >> 32)
            index += 1
        }
    }
}
