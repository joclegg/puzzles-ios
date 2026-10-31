public enum Solver {
    public static func shortest(_ start: Board) -> [Move]? {
        let space = Space(board: start)
        let first = space.key(start)
        if space.isSolved(first) {
            return []
        }
        var parent = KeyMap()
        parent.put(first, first)
        var queue = [first]
        var head = 0
        while head < queue.count {
            let key = queue[head]
            head += 1
            var found: Int64 = -1
            space.forEachNeighbour(key) { next in
                if found < 0 && parent.putIfAbsent(next, key) {
                    if space.isSolved(next) {
                        found = next
                    } else {
                        queue.append(next)
                    }
                }
            }
            if found >= 0 {
                return space.path(parent: parent, start: first, end: found)
            }
        }
        return nil
    }
}

private let positionBits: Int64 = 3
private let positionMask: Int64 = 7

private struct Space {
    let count: Int
    let lengths: [Int]
    let masks: [[Int64]]

    init(board: Board) {
        count = board.blocks.count
        lengths = board.blocks.map(\.length)
        masks = board.blocks.map { block in
            (0..<boardSize).map { position in
                if position + block.length > boardSize {
                    return -1
                }
                return block.movedTo(position).cells.reduce(Int64(0)) { mask, cell in
                    mask | (Int64(1) << Int64(cell))
                }
            }
        }
    }

    func key(_ board: Board) -> Int64 {
        board.blocks.enumerated().reduce(Int64(0)) { key, entry in
            key | (Int64(entry.element.position) << (positionBits * Int64(entry.offset)))
        }
    }

    func position(_ key: Int64, _ block: Int) -> Int {
        Int((key >> (positionBits * Int64(block))) & positionMask)
    }

    func isSolved(_ key: Int64) -> Bool {
        position(key, 0) + lengths[0] == boardSize
    }

    func forEachNeighbour(_ key: Int64, _ action: (Int64) -> Void) {
        var occupied: Int64 = 0
        for block in 0..<count {
            occupied |= masks[block][position(key, block)]
        }
        for block in 0..<count {
            let current = position(key, block)
            let blockMasks = masks[block]
            let others = occupied & ~blockMasks[current]
            let shift = positionBits * Int64(block)
            let cleared = key & ~(positionMask << shift)
            var lower = current - 1
            while lower >= 0 && blockMasks[lower] & others == 0 {
                action(cleared | (Int64(lower) << shift))
                lower -= 1
            }
            var higher = current + 1
            while higher + lengths[block] <= boardSize && blockMasks[higher] & others == 0 {
                action(cleared | (Int64(higher) << shift))
                higher += 1
            }
        }
    }

    func path(parent: KeyMap, start: Int64, end: Int64) -> [Move] {
        var moves: [Move] = []
        var key = end
        while key != start {
            let before = parent.get(key)
            let moved = (0..<count).first { position(key, $0) != position(before, $0) }!
            moves.append(Move(block: moved, position: position(key, moved)))
            key = before
        }
        return moves.reversed()
    }
}

private struct KeyMap {
    private static let empty: Int64 = -1

    private var keys = [Int64](repeating: KeyMap.empty, count: 1024)
    private var values = [Int64](repeating: 0, count: 1024)
    private var size = 0

    func get(_ key: Int64) -> Int64 {
        values[slot(key)]
    }

    mutating func put(_ key: Int64, _ value: Int64) {
        _ = putIfAbsent(key, value)
        values[slot(key)] = value
    }

    mutating func putIfAbsent(_ key: Int64, _ value: Int64) -> Bool {
        let index = slot(key)
        if keys[index] != KeyMap.empty {
            return false
        }
        keys[index] = key
        values[index] = value
        size += 1
        if size * 2 > keys.count {
            grow()
        }
        return true
    }

    private func slot(_ key: Int64) -> Int {
        let last = keys.count - 1
        var index = Int(truncatingIfNeeded: mix(key)) & last
        while keys[index] != KeyMap.empty && keys[index] != key {
            index = (index + 1) & last
        }
        return index
    }

    private mutating func grow() {
        let oldKeys = keys
        let oldValues = values
        keys = [Int64](repeating: KeyMap.empty, count: oldKeys.count * 2)
        values = [Int64](repeating: 0, count: oldKeys.count * 2)
        size = 0
        for index in oldKeys.indices where oldKeys[index] != KeyMap.empty {
            _ = putIfAbsent(oldKeys[index], oldValues[index])
        }
    }

    private func mix(_ key: Int64) -> Int64 {
        let hash = key &* -0x61c8_8646_80b5_83eb
        return hash ^ Int64(bitPattern: UInt64(bitPattern: hash) >> 29)
    }
}
