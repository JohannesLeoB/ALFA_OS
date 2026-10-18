import Foundation
import MykilosKalkulationsCore

public enum BaselineAnchors {
    public static func all() -> [CandidateReleaseDecision] {
        [
            baseline(
                id: "BASE_UC_060_DOOR_SHELF",
                component: "60cm Unterschrank Tür/Fachboden",
                price: 820,
                title: "Konservativer Baseline-Anker für 60cm Unterschrank mit Tür und Fachboden.",
                quote: "Manuell gepflegter Seed-Regelanker; nur für atomare Unterschrank-Anfragen, nicht aus PDF-Angebot.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_UC_060_DRAWERS_SIMPLE",
                component: "60cm Unterschrank einfache Schübe",
                price: 1250,
                title: "Konservativer Baseline-Anker für 60cm Unterschrank mit einfachen Schubkästen.",
                quote: "Manuell gepflegter Seed-Regelanker; verhindert Skalierung von Küchenaggregaten auf Einzelmöbel.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_DRAWER_LEGRABOX",
                component: "Legrabox Schubkasten",
                price: 180,
                title: "Legrabox-Schubkasten als atomarer Beschlagsanker.",
                quote: "Manuell gepflegter Seed-Regelanker je Schubkasten.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_DRAWER_OAK_UPCHARGE",
                component: "Eichenschubkasten Aufpreis",
                price: 140,
                title: "Eiche-Aufpreis pro Schubkasten.",
                quote: "Manuell gepflegter Seed-Regelanker je Eichenschubkasten.",
                componentClass: .baseUnit
            ),
            baseline(
                id: "BASE_LINOL_FRONT_PER_LFM",
                component: "Linoleumfront pro Laufmeter",
                price: 680,
                title: "Linoleumfronten als konservativer Laufmeter-Aufpreis.",
                quote: "Manuell gepflegter Seed-Regelanker je Laufmeter Front.",
                componentClass: .kitchenRun
            ),
            baseline(
                id: "BASE_STAINLESS_FRONT_PER_M2",
                component: "Edelstahlfront pro Quadratmeter",
                price: 950,
                title: "Edelstahlfronten als konservativer Quadratmeter-Aufpreis.",
                quote: "Manuell gepflegter Seed-Regelanker je Quadratmeter Edelstahlfront.",
                componentClass: .island
            )
        ]
    }

    private static func baseline(id: String, component: String, price: Decimal, title: String, quote: String, componentClass: CalculationComponentClass) -> CandidateReleaseDecision {
        CandidateReleaseDecision(
            candidateID: id,
            sourceFile: "RULE_BASED_SEED",
            page: 0,
            supplier: "MYKILOS",
            project: "Baseline",
            component: component,
            trade: "Seed-Regel",
            priceNetGuess: price,
            confidence: 0.62,
            duplicateCount: 1,
            currentStatus: "active",
            proposedStatus: "release_rule_based",
            supersededBy: nil,
            decisionScore: 0.62,
            decisionReason: "Konservativer Baseline-Atom, weil PDF-Korpus keinen ausreichend sauberen atomaren Anker liefert.",
            helpNeeded: "",
            title: title,
            evidenceQuote: quote,
            carryforwardRuleStatus: "not_applicable",
            ruleSafePriceNet: price,
            ruleNotes: "rule_based_anchor; no_delete_policy; nicht aus PDF-Angebot.",
            componentClass: componentClass,
            sourceKind: .ruleBasedAnchor
        )
    }
}
