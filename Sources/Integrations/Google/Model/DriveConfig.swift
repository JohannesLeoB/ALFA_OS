public struct DriveConfig: Codable, Equatable, Sendable {
    public var projectsRoot: String
    public var forbiddenFolderIDs: Set<String>
    public var offers: OfferConvention

    public init(projectsRoot: String, forbiddenFolderIDs: Set<String>, offers: OfferConvention) {
        self.projectsRoot = projectsRoot
        self.forbiddenFolderIDs = forbiddenFolderIDs
        self.offers = offers
    }
}
