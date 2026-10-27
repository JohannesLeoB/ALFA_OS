import Foundation

struct SessionComponent: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let componentIndex: Int
    let componentClass: ComponentClass
    let componentType: ComponentType
    let adjustmentTarget: AdjustmentTarget
    let baseLowNet: Decimal
    let baseMidNet: Decimal
    let baseHighNet: Decimal
    let evidenceIDs: [String]

    init(id: String = UUID().uuidString, sessionID: String, componentIndex: Int, componentClass: ComponentClass, componentType: ComponentType, adjustmentTarget: AdjustmentTarget, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, evidenceIDs: [String]) {
        self.id = id
        self.sessionID = sessionID
        self.componentIndex = componentIndex
        self.componentClass = componentClass
        self.componentType = componentType
        self.adjustmentTarget = adjustmentTarget
        self.baseLowNet = baseLowNet
        self.baseMidNet = baseMidNet
        self.baseHighNet = baseHighNet
        self.evidenceIDs = evidenceIDs
    }
}
