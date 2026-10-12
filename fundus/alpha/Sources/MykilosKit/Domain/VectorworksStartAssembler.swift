import Foundation

public enum VectorworksStartAssembler {
    public static func baue(
        projekt: Project,
        customer: Customer?,
        positionen: [WarenkorbItem] = [],
        vorlageDatei: String,
        raum: String = "Küche",
        erstelltAm: Date
    ) -> CADProjektStart {
        let (strasse, plz, ort) = adresseAus(projekt: projekt)
        return CADProjektStart(
            vorlageDatei: vorlageDatei,
            projectNumber: projekt.projectNumber,
            projectTitle: projekt.title,
            raum: raum,
            customerName: customer?.name ?? projekt.title,
            kundenNummer: customer?.customerNumber ?? leerZuNil(projekt.customerNumber),
            strasse: strasse, plz: plz, ort: ort,
            geraete: positionen.map(geraetAus),
            erstelltAm: erstelltAm)
    }

    static func geraetAus(_ item: WarenkorbItem) -> CADGeraet {
        CADGeraet(
            id: item.id,
            label: item.label,
            articleNumber: leerZuNil(item.articleNumber),
            hersteller: nil,
            quantity: item.quantity)
    }

    static func adresseAus(projekt: Project) -> (strasse: String?, plz: String?, ort: String?) {
        (nil, nil, nil)
    }

    private static func leerZuNil(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), t.isEmpty == false else { return nil }
        return t
    }
}
