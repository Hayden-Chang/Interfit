import Foundation

#if canImport(MusicKit)
import MusicKit
#endif

#if canImport(Security)
import Security
#endif

enum MusicKitPreflight {
    enum EntitlementStatus: Sendable, Equatable {
        case present
        case missing
        case unknown
    }

    static var bundleIdentifier: String? {
        Bundle.main.bundleIdentifier
    }

    static func musicUserTokenEntitlementStatus() -> EntitlementStatus {
        // Prefer checking the running binary entitlements when available.
        #if os(macOS) && canImport(Security)
        guard let task = SecTaskCreateFromSelf(nil) else { return .unknown }
        let key = "com.apple.developer.music-user-token" as CFString
        guard let raw = SecTaskCopyValueForEntitlement(task, key, nil) else { return .missing }

        if CFGetTypeID(raw) == CFBooleanGetTypeID() {
            return (raw as! Bool) ? .present : .missing
        }
        if let number = raw as? NSNumber {
            return number.boolValue ? .present : .missing
        }
        if let string = raw as? NSString {
            let normalized = (string as String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            return (normalized == "true" || normalized == "1") ? .present : .missing
        }
        return .unknown
        #else
        // On iOS we can’t reliably read entitlements via `SecTaskCopyValueForEntitlement`.
        // For dev/ad-hoc builds, we can parse the embedded provisioning profile as a best-effort signal.
        if let entitlements = embeddedMobileProvisionEntitlements(),
           let raw = entitlements["com.apple.developer.music-user-token"] {
            if let bool = raw as? Bool { return bool ? .present : .missing }
            if let number = raw as? NSNumber { return number.boolValue ? .present : .missing }
            if let string = raw as? String {
                let normalized = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                return (normalized == "true" || normalized == "1") ? .present : .missing
            }
            return .unknown
        }

        return .unknown
        #endif
    }

    static func configurationSummary() -> String {
        let bundle = bundleIdentifier ?? "(unknown bundle id)"
        let entitlement: String
        switch musicUserTokenEntitlementStatus() {
        case .present: entitlement = "present"
        case .missing: entitlement = "missing"
        case .unknown: entitlement = "unknown"
        }

        #if canImport(MusicKit)
        let auth = String(describing: MusicAuthorization.currentStatus)
        return "bundle=\(bundle), entitlement=\(entitlement), auth=\(auth)"
        #else
        return "bundle=\(bundle), entitlement=\(entitlement)"
        #endif
    }

    private static func embeddedMobileProvisionEntitlements() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard let text = String(data: data, encoding: .isoLatin1) else { return nil }
        guard let xmlStart = text.range(of: "<?xml")?.lowerBound else { return nil }
        guard let plistEnd = text.range(of: "</plist>")?.upperBound else { return nil }

        let xml = String(text[xmlStart..<plistEnd])
        guard let xmlData = xml.data(using: .utf8) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist["Entitlements"] as? [String: Any]
    }
}
