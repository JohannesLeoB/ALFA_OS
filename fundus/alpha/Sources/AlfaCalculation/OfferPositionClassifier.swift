import Foundation

public enum OfferPositionClassifier {
    public static func classify(text: String) -> ComponentType {
        let t = text.lowercased()
        func has(_ needles: [String]) -> Bool { needles.contains { t.contains($0) } }

        if has(["arbeitsplatte", "naturstein", "quarzit", "quarz", "granit", "keramik",
                "dekton", "silestone", "marmor", "hartgestein", "wange", " apl", "wandabschluss"]) {
            return .stoneCountertop
        }

        if has(["schubkasten", "schublade", "auszug", "besteckeinsatz", "beschlag",
                "kesseböhmer", "kessebohmer", "tandem", "griffleiste", "scharnier"]) {
            return .drawerAddon
        }

        if has(["hochschrank", "apothekerschrank", "vorratsschrank"]) { return .tallCabinetBlock }

        if has(["hängeschrank", "haengeschrank", "oberschrank"]) { return .wallCabinets }

        if has(["kochinsel", "insel"]) { return .island }

        if has(["kochfeld", "backofen", "geschirrspüler", "geschirrspueler", "kühlschrank",
                "kuehlschrank", "gefrier", "dunstabzug", "abzugshaube", "mikrowelle", "spüle",
                "spuele", "armatur", "quooker", "bora", "gaggenau", "miele", "siemens",
                "neff ", "liebherr", "allesschneider"]) {
            return .applianceScope
        }

        if has(["unterschrank", "küchenzeile", "kuechenzeile", "küchenblock", "kuechenblock",
                "korpus", "front", "einbauschrank", "regalböden", "regalboeden"]) {
            return .baseCabinetRun
        }

        if has(["montage", "einbau", "aufbau", "einbringung"]) { return .installation }

        if has(["lieferung", "anlieferung", "anfahrt", "transport", "fahrkosten", "aufmaß",
                "aufmass", "handling", "logistik", "an- und abfahrt", "pauschale", "pflegemittel"]) {
            return .projectLogistics
        }

        if has(["gesamtküche", "gesamtkueche", "komplettküche", "komplettkueche"]) {
            return .aggregateKitchen
        }
        return .other
    }
}
