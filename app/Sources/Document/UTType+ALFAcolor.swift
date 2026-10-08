import UniformTypeIdentifiers

public extension UTType {
    /// Dokumenttyp "ALFAcolor-Dokument": ein Ordnerpaket mit der Endung .alfacolor, erbt von com.apple.package.
    /// Die Konstante allein macht ihn dem System nicht bekannt. Dazu braucht die App einen Export in der Info.plist
    /// (UTExportedTypeDeclarations) und einen Dokumenttyp (CFBundleDocumentTypes); das legt der Chef an, siehe Brief B-104.
    static let alfacolor = UTType(exportedAs: DocumentPackage.typeIdentifier, conformingTo: .package)
}
