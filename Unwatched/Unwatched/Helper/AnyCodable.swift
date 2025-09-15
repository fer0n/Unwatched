//
//  AnyCodable.swift
//  Unwatched
//

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let left as Int, let right as Int):
            return left == right
        case (let left as Double, let right as Double):
            return left == right
        case (let left as String, let right as String):
            return left == right
        case (let left as Bool, let right as Bool):
            return left == right
        default:
            return false
        }
    }

    var asString: String {
        switch value {
        case let intValue as Int:
            return String(intValue)
        case let doubleValue as Double:
            return String(doubleValue)
        case let stringValue as String:
            return stringValue
        case let boolValue as Bool:
            return String(boolValue)
        default:
            return ""
        }
    }
}
