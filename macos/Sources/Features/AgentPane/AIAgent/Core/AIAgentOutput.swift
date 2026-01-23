import Foundation

/// Output types from an AI agent execution
public enum AIAgentOutput: Sendable {
    case text(String)
    case functionCall(FunctionCall)
    case image(Data)
    case audio(Data)
    case error(Error)
    
    public struct FunctionCall: Sendable, Codable {
        public let name: String
        public let arguments: [String: JSONValue]
        
        public init(name: String, arguments: [String: JSONValue]) {
            self.name = name
            self.arguments = arguments
        }
        
        public init?(jsonString: String) {
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String else {
                return nil
            }
            self.name = name
            if let args = json["args"] as? [String: Any],
               let argsData = try? JSONSerialization.data(withJSONObject: args),
               let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: argsData) {
                self.arguments = decoded
            } else {
                self.arguments = [:]
            }
        }
        
        public var argumentsString: String {
            guard let data = try? JSONEncoder().encode(arguments),
                  let str = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return str
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == AIAgentOutput {
    public var allTexts: [String] {
        compactMap {
            if case .text(let text) = $0 { return text }
            return nil
        }
    }
    
    public var firstText: String? {
        allTexts.first
    }
    
    public var allFunctionCalls: [AIAgentOutput.FunctionCall] {
        compactMap {
            if case .functionCall(let call) = $0 { return call }
            return nil
        }
    }
    
    public var hasErrors: Bool {
        contains { if case .error = $0 { return true } else { return false } }
    }
    
    public var errors: [Error] {
        compactMap {
            if case .error(let error) = $0 { return error }
            return nil
        }
    }
}

// MARK: - JSON Value Type

/// A type-safe JSON value for function arguments
public enum JSONValue: Sendable, Codable, Equatable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
    
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    public var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .number(let d) = self { return Int(d) }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .number(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    
    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    
    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    
    public static func from(any: Any) -> JSONValue {
        switch any {
        case let s as String: return .string(s)
        case let i as Int: return .int(i)
        case let d as Double: return .number(d)
        case let b as Bool: return .bool(b)
        case let a as [Any]: return .array(a.map { from(any: $0) })
        case let o as [String: Any]: return .object(o.mapValues { from(any: $0) })
        default: return .null
        }
    }
    
    public func toAny() -> Any {
        switch self {
        case .string(let s): return s
        case .number(let d): return d
        case .int(let i): return i
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let a): return a.map { $0.toAny() }
        case .object(let o): return o.mapValues { $0.toAny() }
        }
    }
}
