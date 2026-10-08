import UniformTypeIdentifiers

public extension UTType {
    /// Document type "ALFAcolor Document": a folder package with the extension .alfacolor. It conforms to com.apple.package.
    /// The constant alone does not make the type known to the system. The app also needs an export in Info.plist
    /// (UTExportedTypeDeclarations) and a document type (CFBundleDocumentTypes). Both are declared in `ALFAcolor/project.yml`.
    static let alfacolor = UTType(exportedAs: DocumentPackage.typeIdentifier, conformingTo: .package)
}
