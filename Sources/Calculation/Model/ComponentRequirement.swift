import Foundation

struct ComponentRequirement: Equatable, Identifiable, Sendable {
    let id: UUID
    let component: EstimateComponent
    let allowedComponentClasses: Set<ComponentClass>
    let forbiddenComponentClasses: Set<ComponentClass>
    let minEvidenceCount: Int
    let maxScaleFactor: Double

    init(id: UUID = UUID(), component: EstimateComponent, allowedComponentClasses: Set<ComponentClass>, forbiddenComponentClasses: Set<ComponentClass>, minEvidenceCount: Int, maxScaleFactor: Double) {
        self.id = id
        self.component = component
        self.allowedComponentClasses = allowedComponentClasses
        self.forbiddenComponentClasses = forbiddenComponentClasses
        self.minEvidenceCount = minEvidenceCount
        self.maxScaleFactor = maxScaleFactor
    }
}
