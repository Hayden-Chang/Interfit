import Foundation
import Shared

enum BuiltinPlanTemplates {
    static let quickStart: [Plan] = [
        Plan(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            setsCount: 6,
            workSeconds: 30,
            restSeconds: 15,
            name: "Beginner"
        ),
        Plan(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            setsCount: 8,
            workSeconds: 40,
            restSeconds: 20,
            name: "Classic"
        ),
        Plan(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            setsCount: 8,
            workSeconds: 20,
            restSeconds: 10,
            name: "Tabata"
        ),
    ]
}

