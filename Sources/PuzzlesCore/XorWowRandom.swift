public struct XorWowRandom: Sendable {
    private var x: Int32
    private var y: Int32
    private var z: Int32 = 0
    private var w: Int32 = 0
    private var v: Int32
    private var addend: Int32

    public init(seed: Int64) {
        self.init(seed1: Int32(truncatingIfNeeded: seed), seed2: Int32(truncatingIfNeeded: seed >> 32))
    }

    public init(intSeed seed: Int32) {
        self.init(seed1: seed, seed2: seed >> 31)
    }

    private init(seed1: Int32, seed2: Int32) {
        x = seed1
        y = seed2
        v = ~seed1
        addend = (seed1 << 10) ^ Int32(bitPattern: UInt32(bitPattern: seed2) >> 4)
        for _ in 0..<64 {
            _ = nextInt()
        }
    }

    public mutating func nextInt() -> Int32 {
        var t = Int32(bitPattern: UInt32(bitPattern: x) >> 2) ^ x
        x = y
        y = z
        z = w
        let v0 = v
        w = v0
        t = t ^ (t << 1) ^ v0 ^ (v0 << 4)
        v = t
        addend = addend &+ 362_437
        return t &+ addend
    }

    public mutating func nextBits(_ count: Int) -> Int32 {
        Int32(bitPattern: UInt32(bitPattern: nextInt()) >> UInt32(32 - count))
    }

    public mutating func nextInt(below until: Int) -> Int {
        precondition(until > 0, "until must be positive")
        let bound = Int32(until)
        if bound & -bound == bound {
            return Int(nextBits(31 - bound.leadingZeroBitCount))
        }
        while true {
            let bits = Int32(bitPattern: UInt32(bitPattern: nextInt()) >> 1)
            let value = bits % bound
            if bits &- value &+ (bound - 1) >= 0 {
                return Int(value)
            }
        }
    }

    public mutating func nextLong() -> Int64 {
        let high = Int64(nextInt())
        let low = Int64(nextInt())
        return (high << 32) &+ low
    }

    public mutating func nextDouble() -> Double {
        let high = Double(nextBits(26))
        let low = Double(nextBits(27))
        return (high * 134_217_728 + low) / 9_007_199_254_740_992
    }

    public mutating func nextBool() -> Bool {
        nextBits(1) != 0
    }
}

extension Array {
    public func shuffled(using random: inout XorWowRandom) -> [Element] {
        var result = self
        var index = result.count - 1
        while index >= 1 {
            result.swapAt(index, random.nextInt(below: index + 1))
            index -= 1
        }
        return result
    }
}
