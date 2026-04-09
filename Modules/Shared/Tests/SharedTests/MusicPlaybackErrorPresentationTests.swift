import XCTest
@testable import Shared

final class MusicPlaybackErrorPresentationTests: XCTestCase {
    func test_infersUnauthorizedFromPermissionText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "The user denied Apple Music permission.")
        XCTAssertEqual(presentation, .unauthorized)
    }

    func test_infersSubscriptionUnavailableFromSubscriptionText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "Playback failed because subscription required.")
        XCTAssertEqual(presentation, .subscriptionUnavailable)
    }

    func test_infersMusicAppUnavailableFromMissingMusicAppText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "The Apple Music app is not installed on this device.")
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableFromSystemApplicationNotInstalledText() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=NSOSStatusErrorDomain Code=-10814 \"The operation couldn’t be completed. Application is not installed.\""
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableWhenNoApplicationCanOpenMusicURL() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=FBSOpenApplicationServiceErrorDomain Code=1 \"No application can open music://\""
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableBeforePrepareFailureWhenBothCluesExist() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\" because the application is not installed.",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "true",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableFromPrepareFailureWhenMusicAppIsMissing() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "false",
            musicAppAvailability: "missing"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableFromGenericPrepareFailureCodeWhenSubscriptionProbeIsUnknown() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "domain=MPMusicPlayerControllerErrorDomain, code=6, description=The operation couldn’t be completed. (MPMusicPlayerControllerErrorDomain error 6.)",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "unknown",
            musicAppAvailability: "unknown",
            subscriptionErrorKind: "unknown"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableFromSubscriptionProbeDescriptionWhenPlaybackErrorIsGeneric() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "domain=MPMusicPlayerControllerErrorDomain, code=6, description=The operation couldn’t be completed. (MPMusicPlayerControllerErrorDomain error 6.)",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "unknown",
            musicAppAvailability: "available",
            subscriptionErrorKind: "unknown",
            subscriptionErrorDescription: "domain=NSOSStatusErrorDomain, code=-10814, description=The operation couldn’t be completed. Application is not installed."
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersMusicAppUnavailableFromNilServerPlaybackError() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "domain=MPMusicPlayerControllerErrorDomain, code=6, description=The operation couldn’t be completed. (MPMusicPlayerControllerErrorDomain error 6.), NSDebugDescription=Prepare to play failed, underlying={domain=MPMusicPlayerControllerErrorDomain, code=10, description=The operation couldn’t be completed. (MPMusicPlayerControllerErrorDomain error 10.), NSDebugDescription=Failed to obtain remoteObject [nil server]}",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "false",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_adjustsSubscriptionUnavailableToMusicAppUnavailableWhenMusicAppMissing() {
        let presentation = MusicPlaybackErrorPresentation.adjustForEnvironment(
            .subscriptionUnavailable,
            musicAppAvailability: "missing"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_adjustsSubscriptionUnavailableToMusicAppUnavailableWhenSubscriptionErrorKindSaysAppUnavailable() {
        let presentation = MusicPlaybackErrorPresentation.adjustForEnvironment(
            .subscriptionUnavailable,
            musicAppAvailability: "available",
            subscriptionErrorKind: "appUnavailable"
        )
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_adjustsSubscriptionUnavailableToConfigurationErrorWhenSubscriptionErrorKindSaysConfiguration() {
        let presentation = MusicPlaybackErrorPresentation.adjustForEnvironment(
            .subscriptionUnavailable,
            musicAppAvailability: "available",
            subscriptionErrorKind: "configuration"
        )
        XCTAssertEqual(presentation, .configurationError)
    }

    func test_errorDescriptionFormatterIncludesUnderlyingApplicationNotInstalledClue() {
        let underlying = NSError(
            domain: NSOSStatusErrorDomain,
            code: -10814,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. Application is not installed."]
        )
        let error = NSError(
            domain: "MPMusicPlayerControllerErrorDomain",
            code: 6,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to prepare to play.",
                NSUnderlyingErrorKey: underlying
            ]
        )

        let description = ErrorDescriptionFormatter.describe(error)
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: description)
        XCTAssertEqual(presentation, .musicAppUnavailable)
    }

    func test_infersConfigurationErrorFromDeveloperTokenText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "DeveloperTokenRequestFailed: client not found (40402)")
        XCTAssertEqual(presentation, .configurationError)
    }

    func test_infersItemUnavailableFromAvailabilityText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "The requested item is unavailable and cannot be played.")
        XCTAssertEqual(presentation, .itemUnavailable)
    }

    func test_infersNetworkUnavailableFromConnectivityText() {
        let presentation = MusicPlaybackErrorPresentation.infer(fromErrorDescription: "The Internet connection appears to be offline.")
        XCTAssertEqual(presentation, .networkUnavailable)
    }

    func test_infersConfigurationErrorFromPrepareFailureWhenEntitlementMissing() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "missing",
            authorizationStatus: "authorized",
            subscriptionAvailable: "true",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .configurationError)
    }

    func test_infersSubscriptionUnavailableFromPrepareFailureWhenSubscriptionMissing() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "false",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .subscriptionUnavailable)
    }

    func test_infersSubscriptionUnavailableFromPrepareFailureBeforeEntitlementWhenSubscriptionMissing() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "missing",
            authorizationStatus: "authorized",
            subscriptionAvailable: "false",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .subscriptionUnavailable)
    }

    func test_infersUnauthorizedFromPrepareFailureWhenAuthorizationDenied() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "present",
            authorizationStatus: "denied",
            subscriptionAvailable: "true",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .unauthorized)
    }

    func test_infersItemUnavailableFromPrepareFailureWhenEnvironmentLooksHealthy() {
        let presentation = MusicPlaybackErrorPresentation.infer(
            fromErrorDescription: "Error Domain=MPMusicPlayerControllerErrorDomain Code=6 \"Failed to prepare to play\"",
            entitlementStatus: "present",
            authorizationStatus: "authorized",
            subscriptionAvailable: "true",
            musicAppAvailability: "available"
        )
        XCTAssertEqual(presentation, .itemUnavailable)
    }
}
