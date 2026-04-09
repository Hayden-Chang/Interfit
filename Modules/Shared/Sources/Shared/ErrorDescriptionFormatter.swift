import Foundation

public enum ErrorDescriptionFormatter {
    public static func describe(_ error: any Error) -> String {
        var visited: Set<ObjectIdentifier> = []
        return describe(error as NSError, visited: &visited)
    }

    private static func describe(_ error: NSError, visited: inout Set<ObjectIdentifier>) -> String {
        let identifier = ObjectIdentifier(error)
        guard visited.insert(identifier).inserted else {
            return "domain=\(error.domain), code=\(error.code)"
        }

        var components: [String] = [
            "domain=\(error.domain)",
            "code=\(error.code)"
        ]

        appendIfPresent(error.localizedDescription, label: "description", to: &components)
        appendIfPresent(error.localizedFailureReason, label: "failureReason", to: &components)
        appendIfPresent(error.localizedRecoverySuggestion, label: "recoverySuggestion", to: &components)

        let keys = error.userInfo.keys
            .map { "\($0)" }
            .sorted()

        for key in keys {
            guard key != NSUnderlyingErrorKey else { continue }
            let rawValue = error.userInfo[key]
            guard let value = stringify(rawValue) else { continue }
            appendIfPresent(value, label: key, to: &components)
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            components.append("underlying={\(describe(underlying, visited: &visited))}")
        } else if let underlying = error.userInfo[NSUnderlyingErrorKey] as? any Error {
            components.append("underlying={\(describe(underlying as NSError, visited: &visited))}")
        }

        return components.joined(separator: ", ")
    }

    private static func appendIfPresent(_ value: String?, label: String, to components: inout [String]) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        components.append("\(label)=\(trimmed)")
    }

    private static func stringify(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let url as URL:
            return url.absoluteString
        case let error as NSError:
            return "domain=\(error.domain), code=\(error.code), description=\(error.localizedDescription)"
        case let error as any Error:
            let nsError = error as NSError
            return "domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)"
        default:
            return nil
        }
    }
}
