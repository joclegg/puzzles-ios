public enum CellChangeCodec {
    public static func encode<Code: RawRepresentable>(_ changes: [(cell: Int, from: Code, to: Code)]) -> String
    where Code.RawValue == Character {
        changes.map { "\($0.cell)\($0.from.rawValue)\($0.to.rawValue)" }.joined(separator: ",")
    }

    public static func decode<Code: RawRepresentable>(_ text: String, as type: Code.Type) -> [(cell: Int, from: Code, to: Code)]?
    where Code.RawValue == Character {
        var changes: [(cell: Int, from: Code, to: Code)] = []
        for part in text.split(separator: ",") {
            guard part.count >= 2,
                let cell = Int(part.dropLast(2)),
                let from = Code(rawValue: part[part.index(part.endIndex, offsetBy: -2)]),
                let to = Code(rawValue: part[part.index(before: part.endIndex)])
            else {
                return nil
            }
            changes.append((cell: cell, from: from, to: to))
        }
        return changes
    }
}
