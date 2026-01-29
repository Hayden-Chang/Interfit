import Foundation

/// Temporary adjustments applied during a Session (M1).
/// - Note: Overrides should not be written back to the Plan unless the user explicitly saves.
public struct SessionOverrides: Sendable, Codable, Equatable {
    public var setsCount: Int?
    public var workSeconds: Int?
    public var restSeconds: Int?
    public var musicSelection: MusicSelection?

    public init(
        setsCount: Int? = nil,
        workSeconds: Int? = nil,
        restSeconds: Int? = nil,
        musicSelection: MusicSelection? = nil
    ) {
        self.setsCount = setsCount
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.musicSelection = musicSelection
    }
}

public extension SessionOverrides {
    var isEmpty: Bool {
        setsCount == nil && workSeconds == nil && restSeconds == nil && musicSelection == nil
    }
}
