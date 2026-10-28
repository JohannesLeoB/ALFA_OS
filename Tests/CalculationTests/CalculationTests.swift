import Core
import Foundation
import GRDB
import Storage
import XCTest
@testable import Calculation

private func numeric(_ decimal: Decimal) -> Double {
    NSDecimalNumber(decimal: decimal).doubleValue
}

private struct FixedPrice: ArticlePricePort {
    let price: Double?

    func purchaseNet(matching term: String) async -> Double? {
        price
    }
}

final class CalculationTests: XCTestCase {
    private func engine(_ params: CarcassParameters = .seed()) -> CarcassEngine {
        CarcassEngine(params: params)
    }

    func testNumberParserReadsGermanFormats() {
        XCTAssertEqual(NumberParser.decimal("1.234,56 €"), Decimal(string: "1234.56"))
        XCTAssertEqual(NumberParser.decimal("12,5"), Decimal(string: "12.5"))
        XCTAssertEqual(NumberParser.decimal("7.5"), Decimal(string: "7.5"))
        XCTAssertEqual(NumberParser.decimal("99 EUR"), Decimal(99))
        XCTAssertNil(NumberParser.decimal("  "))
        XCTAssertEqual(NumberParser.double("2,5"), 2.5)
        XCTAssertEqual(NumberParser.integerWord("Zwölf"), 12)
        XCTAssertEqual(NumberParser.integerWord("fuenfzehn"), 15)
        XCTAssertNil(NumberParser.integerWord("hundert"))
    }

    func testCSVNumberAccessors() {
        let row = ["a": "1.234,50", "b": "x", "c": "2,5", "d": "3.25"]
        XCTAssertEqual(row.decimal("a"), Decimal(string: "1234.5"))
        XCTAssertEqual(row.decimal("b"), 0)
        XCTAssertNil(row.optionalDecimal("b"))
        XCTAssertEqual(row.optionalDecimal("c"), Decimal(string: "2.5"))
        XCTAssertEqual(row.double("c"), 2.5)
        XCTAssertEqual(row.double("d"), 3.25)
        XCTAssertEqual(row.double("missing"), 0)
    }

    func testNoticeAmountRoundsHalfEvenAndRoundTripsJSON() {
        XCTAssertEqual(Notice.amount(Decimal(string: "1234.5")!), "1234")
        XCTAssertEqual(Notice.amount(Decimal(string: "1235.5")!), "1236")
        XCTAssertEqual(Notice.fixed(0.85, digits: 2), "0.85")
        XCTAssertEqual(Notice.measure(20), "20")
        XCTAssertEqual(Notice.measure(1.55), "1.6")
        let notice = Notice("calc.test", ["a", "b"])
        XCTAssertEqual(Notice(json: notice.json), notice)
        XCTAssertNil(Notice(json: "not json"))
    }

    func testSplitMixKnownFirstOutputAndSigmaFormula() {
        var random = SeededRandom(seed: 0)
        XCTAssertEqual(random.next(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(StochasticEngine.sigma(fromRelativeSpread: 0.2), log(1.5) / (2 * 1.2816), accuracy: 1e-12)
        XCTAssertEqual(StochasticEngine.sigma(fromRelativeSpread: 0), 0)
        XCTAssertEqual(StochasticEngine.sigma(fromRelativeSpread: 5), log(1.95 / 0.05) / (2 * 1.2816), accuracy: 1e-12)
        XCTAssertEqual(StochasticEngine.confidence(evidenceScore: 0.8, relativeWidth: 0.2), 0.8, accuracy: 1e-12)
        XCTAssertEqual(StochasticEngine.confidence(evidenceScore: 0.0, relativeWidth: 0.2), 0.1, accuracy: 1e-12)
        XCTAssertEqual(StochasticEngine.confidence(evidenceScore: 1.0, relativeWidth: 0.0), 0.95, accuracy: 1e-12)
    }

    func testStochasticDeterministicComponentsSumWithoutSampling() {
        let summary = StochasticEngine.aggregate(components: [
            .init(median: 100, sigma: 0), .init(median: 50, sigma: 0), .init(median: 0, sigma: 0.3),
        ])
        XCTAssertEqual([summary.low, summary.median, summary.mean, summary.high], [150, 150, 150, 150])
        XCTAssertEqual(StochasticEngine.aggregate(components: []), StochasticEngine.Summary(low: 0, median: 0, mean: 0, high: 0))
        XCTAssertEqual(StochasticEngine.Summary(low: 0, median: 0, mean: 0, high: 0).relativeWidth, 1)
    }

    func testStochasticSingleLognormalMatchesIndependentReference() {
        let sigma = StochasticEngine.sigma(fromRelativeSpread: 0.2)
        let first = StochasticEngine.aggregate(components: [.init(median: 10000, sigma: sigma)])
        let second = StochasticEngine.aggregate(components: [.init(median: 10000, sigma: sigma)])
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.low, 8147.327101881161, accuracy: 1e-6)
        XCTAssertEqual(first.median, 9996.724509551867, accuracy: 1e-6)
        XCTAssertEqual(first.mean, 10116.938611364641, accuracy: 1e-6)
        XCTAssertEqual(first.high, 12236.33393801274, accuracy: 1e-6)
        XCTAssertEqual(first.relativeWidth, 0.20451733126308194, accuracy: 1e-9)
    }

    func testCarcassEngineMelamineSevenCarcassesWithoutExtras() {
        let estimate = engine().estimate(CarcassSpec(carcassCount: 7, frontExecution: .melamine))
        XCTAssertEqual(numeric(estimate.band.expected), 10575.75, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.band.low), 7614.54, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.band.high), 14806.05, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.installationShare), 1871.1, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.furnitureWithoutInstallation), 8704.65, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.fixedCost), 6500)
        XCTAssertEqual(numeric(estimate.variable), 4075.75, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.travel), 0)
        XCTAssertEqual(estimate.excludes, [.worktop, .appliances, .margin])
        XCTAssertEqual(estimate.parameterSnapshot["fixkosten_sockel"], 6500)
        XCTAssertEqual(estimate.parameterSnapshot["front_faktor_melamin"], 0.85)
        XCTAssertEqual(estimate.parameterSnapshot["montage_stundensatz_default"], 81)
        XCTAssertNil(estimate.parameterSnapshot["anfahrt_pro_km"])
    }

    func testCarcassEngineThinPriorUsesWiderBand() {
        let estimate = engine().estimate(CarcassSpec(carcassCount: 7, frontExecution: .stainless))
        XCTAssertEqual(numeric(estimate.band.expected), 13452.75, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.band.low), 8340.705, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.band.high), 21255.345, accuracy: 1e-6)
        XCTAssertTrue(estimate.assumptions.contains(Notice("calc.carcass.thinPrior", ["calc.front.edelstahl"])))
    }

    func testCarcassEngineDrawersTravelAndWorkshopFactor() {
        let params = CarcassParameters.seed(workshopFactors: WorkshopFactors(["stadler": 1.2]))
        let spec = CarcassSpec(carcassCount: 7, frontExecution: .linoleum, drawersLegrabox: 4, drawersSolid: 2, distanceKm: 50, workshop: "Stadler GmbH")
        let estimate = engine(params).estimate(spec)
        XCTAssertEqual(numeric(estimate.drawers), 544, accuracy: 1e-9)
        XCTAssertEqual(numeric(estimate.travel), 160, accuracy: 1e-9)
        XCTAssertEqual(numeric(estimate.band.expected), 14366.8, accuracy: 1e-6)
        XCTAssertEqual(numeric(estimate.installationShare), 2031.1, accuracy: 1e-6)
        XCTAssertEqual(estimate.parameterSnapshot["werkstatt_faktor_stadler"], 1.2)
        XCTAssertEqual(estimate.parameterSnapshot["schub_legrabox_eur"], 70)
        XCTAssertEqual(estimate.parameterSnapshot["schub_holz_eur"], 132)
        XCTAssertEqual(estimate.parameterSnapshot["anfahrt_pro_km"], 8)
    }

    func testCarcassParametersFromOverridesKeepsFallbackForMissingKeys() {
        let params = CarcassParameters.from(
            parameters: ["fixkosten_sockel": 7000, "front_faktor_lack": 1.1, "werkstatt_faktor_x": 1.5, "band_low": 0.5],
            fallback: .seed())
        XCTAssertEqual(params.fixedBase, 7000)
        XCTAssertEqual(params.variablePerCarcass, 685)
        XCTAssertEqual(params.frontMultiplier(for: .lacquer), 1.1)
        XCTAssertEqual(params.frontMultiplier(for: .glass), 1.25)
        XCTAssertEqual(params.workshopFactor(for: "X-Werkstatt"), 1.5)
        XCTAssertEqual(params.workshopFactor(for: nil), 1.0)
        XCTAssertEqual(params.bandLow, 0.5)
        XCTAssertEqual(params.bandHigh, 1.40)
        XCTAssertEqual(params.travelFreeKm, 30)
    }

    func testCarcassSpecFromComponentsCountsCarcassesAndSplitsDrawers() {
        let run = EstimateComponent(type: .baseCabinetRun, quantity: 4.2, unit: "lfm", drawerCount: 4, materials: ["eiche"], componentClass: .kitchenRun)
        let island = EstimateComponent(type: .island, quantity: 1.2, unit: "lfm", widthM: 1.2, componentClass: .island)
        let spec = engine().spec(components: [run, island], scope: ScopeFlags(), distanceKm: 12)
        XCTAssertEqual(spec.carcassCount, 10)
        XCTAssertEqual(spec.frontExecution, .veneer)
        XCTAssertEqual(spec.drawersSolid, 4)
        XCTAssertEqual(spec.drawersLegrabox, 0)
        XCTAssertEqual(spec.distanceKm, 12)
        XCTAssertEqual(spec.installationBasis, .unknown)
        var scope = ScopeFlags()
        scope.includesInstallation = true
        XCTAssertEqual(engine().spec(components: [run], scope: scope, distanceKm: nil).installationBasis, .included)
    }

    func testFrontExecutionInferencePriorityOrder() {
        XCTAssertEqual(FrontExecution.infer(from: ["edelstahl", "linoleum"]), .stainless)
        XCTAssertEqual(FrontExecution.infer(from: ["fenix"]), .linoleum)
        XCTAssertEqual(FrontExecution.infer(from: ["hochglanz"]), .lacquer)
        XCTAssertEqual(FrontExecution.infer(from: ["Eiche"]), .veneer)
        XCTAssertEqual(FrontExecution.infer(from: ["massiv"]), .solidWood)
        XCTAssertEqual(FrontExecution.infer(from: ["glas"]), .glass)
        XCTAssertEqual(FrontExecution.infer(from: ["mdf"]), .melamine)
        XCTAssertEqual(FrontExecution.infer(from: ["stein"]), .unknown)
        XCTAssertEqual(FrontExecution.allCases.map(\.variableMultiplier), [0.85, 1.0, 1.05, 1.05, 1.45, 1.30, 1.25, 1.0])
        XCTAssertEqual(FrontExecution.allCases.filter(\.isThinPrior), [.lacquer, .stainless, .solidWood, .glass])
    }

    func testParserReadsRunMaterialsAndDrawers() {
        let request = EstimateRequestParser().parse("Küche 4,2 lfm Linoleum mit 6 Schubkästen")
        XCTAssertEqual(request.components.count, 1)
        let run = request.components[0]
        XCTAssertEqual(run.type, .baseCabinetRun)
        XCTAssertEqual(run.quantity, 4.2)
        XCTAssertEqual(run.unit, "lfm")
        XCTAssertEqual(run.componentClass, .kitchenRun)
        XCTAssertEqual(run.drawerCount, 6)
        XCTAssertEqual(request.materials, ["linoleum"])
    }

    func testParserReadsIslandFootprintAndBaseUnitWidth() {
        let island = EstimateRequestParser().parse("Insel 2,4 x 1 m").components
        XCTAssertEqual(island.count, 1)
        XCTAssertEqual(island[0].type, .island)
        XCTAssertEqual(island[0].unit, "m2")
        XCTAssertEqual(island[0].quantity, 2.4, accuracy: 1e-12)
        XCTAssertEqual(island[0].widthM, 2.4)
        XCTAssertEqual(island[0].heightM, 1)
        let unit = EstimateRequestParser().parse("60cm Unterschrank").components
        XCTAssertEqual(unit.count, 1)
        XCTAssertEqual(unit[0].componentClass, .baseUnit)
        XCTAssertEqual(unit[0].unit, "piece")
        XCTAssertEqual(unit[0].widthM, 0.6)
    }

    func testParserCapsImplausibleSizesAndKeepsMarkers() {
        let component = EstimateRequestParser().parse("35 lfm Küchenzeile").components[0]
        XCTAssertEqual(component.quantity, 20)
        XCTAssertTrue(component.scopeNotes.contains(.sizeImplausible))
        XCTAssertTrue(component.scopeNotes.contains(Notice("calc.note.sizeImplausible", ["35", "lfm", "20"])))
        let guessed = EstimateRequestParser().parse("Küchenzeile mit Insel").components.first { $0.type == .baseCabinetRun }
        XCTAssertEqual(guessed?.quantity, 4)
        XCTAssertTrue(guessed?.scopeNotes.contains(.sizeEstimated) == true)
    }

    func testParserScopeFlagsAndFallbackComponent() {
        let scope = EstimateRequestParser().parse("Küche 5 lfm ohne Geräte, ohne Arbeitsplatte, mit Montage und Lieferung").scope
        XCTAssertTrue(scope.excludesAppliances)
        XCTAssertTrue(scope.excludesWorktop)
        XCTAssertTrue(scope.includesInstallation)
        XCTAssertTrue(scope.includesDelivery)
        XCTAssertEqual(scope.notes.map(\.key), [
            "calc.scope.appliancesExcluded", "calc.scope.worktopExcluded",
            "calc.scope.deliveryIncluded", "calc.scope.installationIncluded",
        ])
        let unknown = EstimateRequestParser().parse("hallo")
        XCTAssertEqual(unknown.components.map(\.type), [.other])
        XCTAssertEqual(unknown.scope.notes, [Notice("calc.scope.unmapped")])
    }

    func testParserSingleKeywordsTriggerComponentsAndScope() {
        let parser = EstimateRequestParser()
        XCTAssertEqual(parser.parse("gesamtkuche").components.map(\.type), [.aggregateKitchen])
        XCTAssertTrue(parser.parse("ohne anschlüsse").scope.excludesAppliances)
        XCTAssertEqual(parser.parse("4 lfm Küchenzeile mit Montage").components.map(\.type), [.baseCabinetRun, .installation])
        XCTAssertEqual(CandidateReleaseDecision.classify(component: "Transport", trade: "", title: "", evidenceQuote: "", proposedStatus: ""), .logistics)
    }

    func testAnchorLengthReadsMetersButNotMillimeters() {
        func anchor(_ title: String, _ quote: String = "") -> CandidateReleaseDecision {
            CandidateReleaseDecision(candidateID: "A", sourceFile: "f", page: 1, supplier: "s", project: "p", component: "c", trade: "t", priceNetGuess: 1000, confidence: 0.5, duplicateCount: 0, currentStatus: "x", proposedStatus: "release_x", supersededBy: nil, decisionScore: 0.5, decisionReason: "", helpNeeded: "", title: title, evidenceQuote: quote, carryforwardRuleStatus: "", ruleSafePriceNet: nil, ruleNotes: "")
        }
        XCTAssertNil(anchor("Platte 19mm Eiche").lengthM)
        XCTAssertNil(anchor("Platte 19 mm").lengthM)
        XCTAssertEqual(anchor("Zeile 3,5 m Eiche").lengthM, 3.5)
        XCTAssertEqual(anchor("Zeile", "4 Meter Front").lengthM, 4)
        XCTAssertEqual(anchor("Zeile 2 lfm").lengthM, 2)
        XCTAssertNil(anchor("Fläche 5 m2").lengthM)
    }

    func testMaterialLexiconRecognisesMaterialsAndHasUniqueEntries() {
        let lexicon = MaterialLexicon.shared
        XCTAssertEqual(lexicon.materialCanonicals(in: "eichenfront mit linoleum und edelstahl"), ["eiche", "linoleum", "edelstahl"])
        XCTAssertEqual(lexicon.materialCanonicals(in: "Rückwand aus Mineralwerkstoff"), ["hi-macs"])
        XCTAssertEqual(lexicon.materialCanonicals(in: "wrichenfurnier"), ["eiche", "furnier"])
        XCTAssertTrue(lexicon.mentionsWorktopSurface(in: "granit arbeitsplatte"))
        XCTAssertFalse(lexicon.mentionsWorktopSurface(in: "eiche fronten"))
        XCTAssertTrue(lexicon.mentionsWorktopSurface(in: "granit"))
        XCTAssertTrue(lexicon.mentionsWorktopSurface(in: "fenix"))
        let names = lexicon.entries.map(\.canonical)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains { $0.hasSuffix("_extra") })
        XCTAssertEqual(lexicon.entries.filter { $0.canonical == "schubkasten" }.count, 1)
    }

    func testEquipmentDensityThresholdsAndCompatibility() {
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: 0), .none)
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: 1.5), .low)
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: 3.0), .medium)
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: 4.5), .high)
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: 4.6), .veryHigh)
        XCTAssertEqual(EquipmentDensity.classify(drawersPerLfm: nil), .unknown)
        XCTAssertEqual(EquipmentDensity.classifyQuery(drawerCount: 6, lengthM: 2), .medium)
        XCTAssertEqual(EquipmentDensity.classifyQuery(drawerCount: 0, lengthM: 2), .unknown)
        XCTAssertTrue(EquipmentDensity.none.isHardIncompatible(with: .medium))
        XCTAssertFalse(EquipmentDensity.low.isHardIncompatible(with: .medium))
        XCTAssertFalse(EquipmentDensity.unknown.isHardIncompatible(with: .veryHigh))
        XCTAssertEqual(EquipmentDensity(rawCorpus: " Very_High "), .veryHigh)
        XCTAssertEqual(EquipmentDensity(rawCorpus: "x"), .unknown)
    }

    func testCarryforwardRuleFlagsSumLines() {
        XCTAssertTrue(CarryforwardRule.isForbiddenContext("Zwischensumme 1.200"))
        XCTAssertTrue(CarryforwardRule.isForbiddenContext("zzgl. MwSt"))
        XCTAssertFalse(CarryforwardRule.isForbiddenContext("Unterschrank 60 cm"))
    }

    func testAnchorInflationFactorsAndYearParsing() {
        XCTAssertEqual(AnchorInflation.year(from: "12.03.2021"), 2021)
        XCTAssertNil(AnchorInflation.year(from: "12.03.1850"))
        XCTAssertEqual(AnchorInflation.year(from: "01.01.2100"), 2100)
        XCTAssertNil(AnchorInflation.year(from: "01.01.2101"))
        XCTAssertNil(AnchorInflation.year(from: nil))
        XCTAssertEqual(numeric(AnchorInflation.factor(offerYear: 2020, referenceYear: 2026)), pow(1.04, 6), accuracy: 1e-9)
        XCTAssertEqual(numeric(AnchorInflation.factor(offerYear: 2010, referenceYear: 2026)), pow(1.04, 6), accuracy: 1e-9)
        XCTAssertEqual(AnchorInflation.factor(offerYear: 2026, referenceYear: 2026), 1)
        XCTAssertEqual(AnchorInflation.factor(offerYear: nil, referenceYear: 2026), 1)
        XCTAssertEqual(AnchorInflation.confidenceFactor(offerYear: 2024, referenceYear: 2026), 0.88, accuracy: 1e-12)
        XCTAssertEqual(AnchorInflation.confidenceFactor(offerYear: 2000, referenceYear: 2026), 0.64, accuracy: 1e-12)
        XCTAssertEqual(AnchorInflation.confidenceFactor(offerYear: nil, referenceYear: 2026), 0.7)
    }

    func testBottomUpFloorForSingleBaseUnit() {
        let unit = EstimateComponent(type: .baseCabinetRun, quantity: 1, unit: "piece", widthM: 0.6, componentClass: .baseUnit)
        let floor = BottomUpCostEngine().estimate(components: [unit])
        XCTAssertEqual(floor.carcassEquivalents, 1, accuracy: 1e-12)
        XCTAssertEqual(floor.frontAreaM2, 0.432, accuracy: 1e-12)
        XCTAssertEqual(numeric(floor.laborNet), 520.5, accuracy: 1e-9)
        XCTAssertEqual(numeric(floor.materialNet), 26.4286 + 14.02 * 0.432, accuracy: 1e-9)
        XCTAssertEqual(numeric(floor.total), 552.98524, accuracy: 1e-9)
        XCTAssertEqual(floor.stageBreakdown.map(\.stage).count, 8)
        XCTAssertEqual(floor.stageBreakdown[0].stage, "calc.stage.preparation")
        XCTAssertEqual(numeric(floor.stageBreakdown[7].cost), 164, accuracy: 1e-9)
        let none = BottomUpCostEngine().estimate(components: [EstimateComponent(type: .delivery, quantity: 1, unit: "scope")])
        XCTAssertEqual(none.total, 0)
        XCTAssertTrue(none.assumptions.isEmpty)
    }

    func testBottomUpFrontPriceByMaterial() {
        XCTAssertEqual(CostModel.frontPrice(materials: ["eiche"]).price, Decimal(string: "21.90")!)
        XCTAssertEqual(CostModel.frontPrice(materials: ["fenix"]).price, Decimal(string: "27.55")!)
        XCTAssertEqual(CostModel.frontPrice(materials: ["linoleum"]).price, Decimal(string: "45.00")!)
        XCTAssertEqual(CostModel.frontPrice(materials: ["mdf"]).price, Decimal(string: "16.56")!)
        XCTAssertEqual(CostModel.frontPrice(materials: []).price, Decimal(string: "14.02")!)
    }

    func testEvidenceEngineAnchorsSingleBaseUnitOnSeedAnchors() throws {
        let request = EstimateRequestParser().parse("60cm Unterschrank")
        let result = EvidenceEngine().estimate(request, anchors: try SeedAnchors().activeAnchors(), factors: [])
        XCTAssertEqual(result.lines.count, 1)
        XCTAssertEqual(result.evidence.map(\.priceAnchorID), ["BASE_UC_060_DOOR_SHELF"])
        let band = result.lines[0].priceBand
        XCTAssertEqual(numeric(band.expected), 820, accuracy: 1e-6)
        XCTAssertEqual(numeric(band.low), 705.2, accuracy: 1e-6)
        XCTAssertEqual(numeric(band.high), 934.8, accuracy: 1e-6)
        XCTAssertEqual(result.baseTotalBand.low, 711)
        XCTAssertEqual(result.baseTotalBand.expected, 824)
        XCTAssertEqual(result.baseTotalBand.high, 944)
        XCTAssertEqual(result.totalBand, result.baseTotalBand)
        XCTAssertEqual(numeric(result.laborValue), 824 * 0.42, accuracy: 1e-9)
        XCTAssertEqual(result.confidence, 0.72947746064847, accuracy: 1e-9)
        XCTAssertTrue(result.dataGaps.isEmpty)
        XCTAssertEqual(numeric(result.bottomUpCost?.total ?? 0), 552.98524, accuracy: 1e-9)
        XCTAssertEqual(result.scopeNotes, [Notice("calc.scope.default")])
        XCTAssertEqual(result.lines[0].rationale.key, "calc.rationale")
        XCTAssertEqual(result.lines[0].evidence[0].scope, "base_unit · rule_based_anchor")
    }

    func testEvidenceEngineReportsShortAndMissingEvidence() throws {
        let anchors = try SeedAnchors().activeAnchors()
        let island = EvidenceEngine().estimate(EstimateRequestParser().parse("Insel 2 x 1 m"), anchors: anchors, factors: [])
        XCTAssertEqual(island.lines.count, 1)
        XCTAssertEqual(island.lines[0].priceBand.expected, 0)
        XCTAssertEqual(island.baseTotalBand.expected, 0)
        XCTAssertEqual(island.dataGaps, [Notice("calc.gap.evidenceShort", ["1", "2", "calc.componentType.island"]), Notice("calc.gap.belowFloor", ["2955"])])
        XCTAssertEqual(island.confidence, (0.58 * 0.1).squareRoot(), accuracy: 1e-12)

        let worktop = EvidenceEngine().estimate(EstimateRequestParser().parse("Granit Arbeitsplatte"), anchors: anchors, factors: [])
        XCTAssertTrue(worktop.lines.isEmpty)
        XCTAssertEqual(worktop.dataGaps, [
            Notice("calc.gap.evidenceShort", ["0", "2", "calc.componentType.stone_countertop"]),
            Notice("calc.gap.missingComponents", ["1"]),
        ])
        XCTAssertEqual(worktop.confidence, 0.1, accuracy: 1e-12)
        XCTAssertEqual(worktop.excludedRisks.count, 5)
    }

    func testEvidenceEngineAppliesOnlyActiveFactors() throws {
        let factor = ActiveFactor(candidateID: "C", reason: .gutFeeling, target: .wholeEstimate, multiplier: Decimal(string: "1.1")!, weightedPercentDelta: 10, sampleCount: 3)
        let inactive = ActiveFactor(candidateID: "D", reason: .marketPrice, target: .wholeEstimate, multiplier: 2, weightedPercentDelta: 100, sampleCount: 9, status: .inactive)
        let base = EstimateRequestParser().parse("60cm Unterschrank")
        let anchors = try SeedAnchors().activeAnchors()
        let plain = EvidenceEngine().estimate(base, anchors: anchors, factors: [])
        let tuned = EvidenceEngine().estimate(base, anchors: anchors, factors: [factor, inactive])
        XCTAssertEqual(tuned.baseTotalBand, plain.baseTotalBand)
        XCTAssertEqual(numeric(tuned.totalBand.expected), 824 * 1.1, accuracy: 1e-9)
        XCTAssertEqual(numeric(tuned.totalBand.low), 711 * 1.1, accuracy: 1e-9)
        XCTAssertEqual(numeric(tuned.totalBand.high), 944 * 1.1, accuracy: 1e-9)
        XCTAssertEqual(tuned.calibrationApplications.map(\.factorID), [factor.id])
        XCTAssertEqual(numeric(tuned.calibrationApplications[0].appliedDeltaNet), 82.4, accuracy: 1e-9)
    }

    func testResolverAddsDrawerAndLogisticsLines() {
        let request = EstimateRequestParser().parse("Küche 4 lfm mit 6 Schubkästen und Insel 2 x 1 m")
        let requirements = ComponentResolveEngine().resolve(request)
        XCTAssertEqual(requirements.map(\.component.type), [.baseCabinetRun, .drawerAddon, .island, .delivery])
        XCTAssertEqual(requirements[0].minEvidenceCount, 2)
        XCTAssertEqual(requirements[0].maxScaleFactor, 1.8)
        XCTAssertEqual(requirements[1].allowedComponentClasses, [.baseUnit])
        XCTAssertEqual(requirements[1].maxScaleFactor, 1.4)
        XCTAssertEqual(requirements[1].component.quantity, 6)
        XCTAssertEqual(requirements[3].allowedComponentClasses, [.logistics])
        XCTAssertEqual(requirements[3].component.unit, "scope")
    }

    func testResolverTurnsShortRunIntoUnitAndKeepsDrawerMaterials() {
        let short = ComponentResolveEngine().resolve(EstimateRequestParser().parse("1 lfm Küchenzeile"))
        XCTAssertEqual(short.count, 1)
        XCTAssertEqual(short[0].component.unit, "piece")
        XCTAssertEqual(short[0].component.componentClass, .baseUnit)
        let drawers = ComponentResolveEngine().resolve(EstimateRequestParser().parse("Küche 4 lfm Eiche Linoleum mit 6 Schubkästen"))
        XCTAssertEqual(drawers[1].component.type, .drawerAddon)
        XCTAssertEqual(drawers[1].component.materials, ["eiche"])
    }

    private func offer(_ id: String, title: String, score: Double, confidence: Double = 0.5, price: Decimal = 1000, density: EquipmentDensity = .unknown) -> CandidateReleaseDecision {
        CandidateReleaseDecision(candidateID: id, sourceFile: "f", page: 1, supplier: "s", project: "p", component: "", trade: "", priceNetGuess: price, confidence: confidence, duplicateCount: 0, currentStatus: "x", proposedStatus: "release_x", supersededBy: nil, decisionScore: score, decisionReason: "", helpNeeded: "", title: title, evidenceQuote: "", carryforwardRuleStatus: "", ruleSafePriceNet: nil, ruleNotes: "", componentClass: .kitchenRun, equipmentDensity: density)
    }

    private func runRequirement(quantity: Double, drawers: Int = 0) -> ComponentRequirement {
        let run = EstimateComponent(type: .baseCabinetRun, quantity: quantity, unit: "lfm", drawerCount: drawers, componentClass: .kitchenRun)
        return ComponentRequirement(component: run, allowedComponentClasses: [.kitchenRun], forbiddenComponentClasses: [], minEvidenceCount: 2, maxScaleFactor: 1.8)
    }

    func testCandidateSelectionScoresDensityAndDropsZeroScores() {
        let engine = ComponentEstimateEngine()
        let ranked = engine.selectCandidates(for: runRequirement(quantity: 4), anchors: [
            offer("A", title: "60cm Zeile", score: 0.2),
            offer("B", title: "Zeile", score: 0.5),
            offer("Z", title: "Zeile", score: 0, confidence: 0),
        ])
        XCTAssertEqual(ranked.map(\.candidateID), ["B", "A"])
        let dense = engine.selectCandidates(for: runRequirement(quantity: 2, drawers: 6), anchors: [
            offer("N", title: "Zeile", score: 0.5, density: .none),
            offer("M", title: "Zeile", score: 0.5, density: .medium),
        ])
        XCTAssertEqual(dense.map(\.candidateID), ["M"])
    }

    func testOfferPriceScalesByLengthWithinBounds() {
        let engine = ComponentEstimateEngine()
        let source = [offer("L", title: "Zeile 2 m", score: 0.5)]
        XCTAssertEqual(numeric(engine.price(requirement: runRequirement(quantity: 3), candidates: source)), 1500, accuracy: 1e-6)
        XCTAssertEqual(numeric(engine.price(requirement: runRequirement(quantity: 10), candidates: source)), 1800, accuracy: 1e-6)
        XCTAssertEqual(numeric(engine.price(requirement: runRequirement(quantity: 0.5), candidates: source)), 350, accuracy: 1e-6)
    }

    func testSeedAnchorsAreTheSixRuleBasedBaselines() throws {
        let anchors = try SeedAnchors().activeAnchors()
        XCTAssertEqual(anchors.map(\.candidateID), [
            "BASE_UC_060_DOOR_SHELF", "BASE_UC_060_DRAWERS_SIMPLE", "BASE_DRAWER_LEGRABOX",
            "BASE_DRAWER_OAK_UPCHARGE", "BASE_LINOL_FRONT_PER_LFM", "BASE_STAINLESS_FRONT_PER_M2",
        ])
        XCTAssertEqual(anchors.map { numeric($0.priceNetGuess) }, [820, 1250, 180, 140, 680, 950])
        XCTAssertTrue(anchors.allSatisfy { $0.sourceKind == .ruleBasedAnchor && $0.confidence == 0.62 && $0.supplier == "calc.seed.supplier" })
        XCTAssertEqual(anchors.map(\.componentClass), [.baseUnit, .baseUnit, .baseUnit, .baseUnit, .kitchenRun, .island])
    }

    func testCorpusRowBecomesAnchorAndScopeDensityEnriches() throws {
        let row = ["candidate_id": "X1", "price_net": "1.500,00", "confidence": "0,8", "component_class": "island", "materials": "eiche", "dimension_raw": "2 m", "page_start": "3", "supplier": "S"]
        let anchor = try XCTUnwrap(CorpusAnchorStore.anchor(from: row))
        XCTAssertEqual(anchor.priceNetGuess, 1500)
        XCTAssertEqual(anchor.confidence, 0.8)
        XCTAssertEqual(anchor.page, 3)
        XCTAssertEqual(anchor.componentClass, .island)
        XCTAssertEqual(anchor.title, "island eiche 2 m")
        XCTAssertEqual(anchor.currentStatus, "release_candidate")
        XCTAssertNil(CorpusAnchorStore.anchor(from: ["candidate_id": "X2", "price_net": "0"]))
        XCTAssertNil(CorpusAnchorStore.anchor(from: ["candidate_id": "X3", "price_net": "5", "superseded_by_candidate": "X1"]))
        let density = ScopeDensityEngine(csv: "candidate_id,equipment_density\nX1,high\nX9,bogus\n")
        XCTAssertEqual(density.enrich([anchor])[0].equipmentDensity, .high)
        XCTAssertEqual(ScopeDensityEngine(densityByCandidate: [:]).enrich([anchor])[0].equipmentDensity, .unknown)
    }

    func testMigrationCreatesLearningTables() throws {
        let store = try SQLiteStore.inMemory()
        let tables = try store.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }
        let expected: Set<String> = [
            "estimate_sessions", "estimate_session_components", "estimate_adjustments",
            "estimate_adjustment_component_targets", "calibration_factor_candidates", "active_calibration_factors",
            "learning_audit_log", "review_actions", "carcass_session_snapshots", "carcass_adjustments",
            "carcass_calibration_candidates", "supplier_offer_sync", "pdf_extracted_positions",
        ]
        XCTAssertTrue(expected.isSubset(of: Set(tables)))
        XCTAssertFalse(tables.contains("document_imports"))
        XCTAssertFalse(tables.contains("learning_metadata"))
    }

    func testLearningStoreOfferAndPdfAnchorChain() throws {
        let store = LearningStore(database: try SQLiteStore.inMemory())
        let offers = [
            SupplierOffer(sourceRecordID: "rec1", kind: .incoming, partner: "Tischlerei A", date: "03.05.2021", netEur: 1000, status: .accepted),
            SupplierOffer(sourceRecordID: "rec2", kind: .incoming, partner: "B", date: "", netEur: 500, status: .open),
            SupplierOffer(sourceRecordID: "rec3", kind: .outgoing, partner: "C", date: "", netEur: 500, status: .accepted),
        ]
        let report = try store.syncOffers(offers)
        XCTAssertEqual([report.fetched, report.imported, report.skippedNoSignal, report.skippedDuplicate], [3, 1, 2, 0])
        XCTAssertEqual(try store.syncOffers(offers).skippedDuplicate, 1)
        XCTAssertEqual(try store.pendingOffers().map(\.sourceRecordID), ["rec1"])
        XCTAssertTrue(try LearnedAnchorStore(store: store, referenceYear: 2026).activeAnchors().isEmpty)
        try store.confirmOffer(sourceRecordID: "rec1")
        XCTAssertTrue(try store.pendingOffers().isEmpty)
        let learned = try LearnedAnchorStore(store: store, referenceYear: 2026).activeAnchors()
        XCTAssertEqual(learned.count, 1)
        XCTAssertEqual(learned[0].candidateID, "LEARNED-rec1")
        XCTAssertEqual(learned[0].componentClass, .aggregateKitchen)
        XCTAssertEqual(numeric(learned[0].priceNetGuess), 1000 * pow(1.04, 5), accuracy: 1e-6)
        XCTAssertEqual(learned[0].confidence, 0.75 * 0.7, accuracy: 1e-12)

        let position = PdfPosition(id: "p1", sourceFile: "a.pdf", pageNumber: 2, title: "Insel", componentType: .island, netPrice: 4000, unit: "scope", quantity: 1, confidence: 0.9, extractedAt: Date())
        XCTAssertEqual(try store.importPdfPositions([position, position]).imported, 1)
        XCTAssertEqual(try store.pendingPdfPositions().map(\.id), ["p1"])
        XCTAssertTrue(try PdfAnchorStore(store: store).activeAnchors().isEmpty)
        try store.confirmPdfPosition(recordID: "p1")
        let pdf = try PdfAnchorStore(store: store).activeAnchors()
        XCTAssertEqual(pdf.count, 1)
        XCTAssertEqual(pdf[0].componentClass, .island)
        XCTAssertEqual(pdf[0].confidence, 0.9 * 0.85, accuracy: 1e-12)

        let composite = CompositeAnchorStore(primary: SeedAnchors(), learned: LearnedAnchorStore(store: store, referenceYear: 2026), pdfLearned: PdfAnchorStore(store: store))
        XCTAssertEqual(try composite.activeAnchors().count, 6 + 1 + 1)
    }

    func testEngineKitchenPathUsesCarcassModelAndStoresSession() async throws {
        let database = try SQLiteStore.inMemory()
        let learning = LearningStore(database: database)
        let engine = EstimationEngine(anchors: SeedAnchors(), learningStore: learning)
        let estimate = try await engine.estimate(projectID: "P1", text: "Küche 4,2 lfm Linoleum")
        XCTAssertEqual(estimate.midNet, 11295, accuracy: 1e-6)
        XCTAssertEqual(estimate.minNet, 11295 * 0.72, accuracy: 1e-6)
        XCTAssertEqual(estimate.maxNet, 11295 * 1.40, accuracy: 1e-6)
        XCTAssertEqual(estimate.confidence, 0.65)
        XCTAssertEqual(estimate.projectID, "P1")
        XCTAssertEqual(estimate.modelLabel, Notice("calc.model.carcass"))
        XCTAssertEqual(estimate.excludes.count, 3)
        XCTAssertEqual(estimate.lines.count, 5)
        XCTAssertEqual(estimate.lines[0].amountNet ?? 0, 11295 - 1871.1, accuracy: 1e-6)
        XCTAssertEqual(estimate.lines[1].amountNet ?? 0, 1871.1, accuracy: 1e-6)
        XCTAssertEqual(estimate.lines[2].kind, .open)
        XCTAssertEqual(estimate.hints.last, Notice("calc.hint.openFields", ["calc.field.carcassCount", "calc.field.frontExecution", "calc.field.workshop"]))
        XCTAssertEqual(try learning.summary().sessions, 1)

        let snapshotCount = try database.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM carcass_session_snapshots") ?? 0 }
        XCTAssertEqual(snapshotCount, 1)
        let fixed = try await engine.estimate(projectID: nil, text: "Küche", override: EstimateOverride(carcassCount: 5, frontExecution: "Edelstahl", workshop: "Stadler", distanceKm: 40))
        XCTAssertEqual(fixed.projectID, "no-project")
        XCTAssertEqual(fixed.midNet, 11546.25, accuracy: 1e-6)
        XCTAssertEqual(fixed.minNet, fixed.midNet * 0.62, accuracy: 1e-6)
        XCTAssertEqual(fixed.maxNet, fixed.midNet * 1.58, accuracy: 1e-6)
        XCTAssertFalse(fixed.hints.contains { $0.key == "calc.hint.openFields" })
        let assumed = try await engine.estimate(projectID: nil, text: "Küche")
        XCTAssertEqual(assumed.hints.first, Notice("calc.hint.sizeMissing"))
        XCTAssertEqual(assumed.midNet, 11295, accuracy: 1e-6)
        let plain = try await engine.estimate(projectID: nil, text: "Küche 6 lfm Linoleum")
        let zero = try await engine.estimate(projectID: nil, text: "Küche 6 lfm Linoleum", override: EstimateOverride(carcassCount: 0))
        XCTAssertEqual(zero.midNet, plain.midNet, accuracy: 1e-6)
        XCTAssertFalse(zero.hints.contains(Notice("calc.hint.sizeMissing")))
    }

    func testEngineEvidencePathLearningLoopAppliesPromotedFactor() async throws {
        let learning = LearningStore(database: try SQLiteStore.inMemory())
        let engine = EstimationEngine(anchors: SeedAnchors(), learningStore: learning)
        let first = try await engine.estimate(projectID: nil, text: "60cm Unterschrank")
        XCTAssertEqual(first.minNet, 711)
        XCTAssertEqual(first.midNet, 824)
        XCTAssertEqual(first.maxNet, 944)
        XCTAssertEqual(first.evidenceCount, 1)
        XCTAssertEqual(first.topEvidence.map(\.supplier), ["calc.seed.supplier"])
        XCTAssertEqual(first.topEvidence[0].netPrice, 820)
        XCTAssertEqual(first.costFloor, 552.98524, accuracy: 1e-9)
        XCTAssertEqual(first.costFloorRatio, 552.98524 / 824, accuracy: 1e-9)

        for _ in 0..<2 {
            try await engine.recordAdjustment(estimateID: first.estimateID, factor: 1.1, ground: "g", learn: true)
        }
        var snapshot = try await engine.learningSnapshot()
        XCTAssertEqual(snapshot.sessions, 1)
        XCTAssertEqual(snapshot.adjustments, 2)
        XCTAssertTrue(snapshot.isEmpty)
        try await engine.recordAdjustment(estimateID: first.estimateID, factor: 1.1, ground: "g", learn: true)
        snapshot = try await engine.learningSnapshot()
        XCTAssertEqual(snapshot.candidates.map(\.id), ["CAL-gut_feeling-whole_estimate"])
        XCTAssertEqual(snapshot.candidates[0].status, .candidate)
        XCTAssertEqual(snapshot.candidates[0].sampleCount, 3)
        XCTAssertEqual(snapshot.candidates[0].percent, 10, accuracy: 1e-6)
        XCTAssertTrue(snapshot.activeFactors.isEmpty)

        try await engine.promote(candidateID: "CAL-gut_feeling-whole_estimate")
        snapshot = try await engine.learningSnapshot()
        XCTAssertEqual(snapshot.activeFactors.count, 1)
        XCTAssertEqual(snapshot.activeFactors[0].target, .wholeEstimate)
        let second = try await engine.estimate(projectID: nil, text: "60cm Unterschrank")
        XCTAssertEqual(second.midNet, 824 * 1.1, accuracy: 1e-4)
        XCTAssertEqual(second.minNet, 711 * 1.1, accuracy: 1e-4)
        XCTAssertEqual(second.maxNet, 944 * 1.1, accuracy: 1e-4)

        do {
            try await engine.promote(candidateID: "missing")
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LearningFailure, .candidateNotFound("missing"))
        }
        do {
            try await engine.recordAdjustment(estimateID: "nope", factor: 1.2, ground: "g", learn: false)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LearningFailure, .sessionNotFound("nope"))
        }
    }

    func testEngineCarcassCorrectionLoopNeedsSnapshotAndKnownTarget() async throws {
        let learning = LearningStore(database: try SQLiteStore.inMemory())
        let engine = EstimationEngine(anchors: SeedAnchors(), learningStore: learning)
        let estimate = try await engine.estimate(projectID: nil, text: "Küche 4,2 lfm Linoleum")
        for _ in 0..<3 {
            try await engine.recordCarcassCorrection(estimateID: estimate.estimateID, targetKey: "variabel_pro_korpus", observedNet: 719.25, reason: .realOfferReceived, note: "", learn: true)
        }
        let (count, recordID, samples, status, current, proposed) = try learning.database.read { db in
            (
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM carcass_calibration_candidates") ?? 0,
                try String.fetchOne(db, sql: "SELECT recordID FROM carcass_calibration_candidates") ?? "",
                try Int.fetchOne(db, sql: "SELECT sampleCount FROM carcass_calibration_candidates") ?? 0,
                try String.fetchOne(db, sql: "SELECT status FROM carcass_calibration_candidates") ?? "",
                try Double.fetchOne(db, sql: "SELECT currentValue FROM carcass_calibration_candidates") ?? 0,
                try Double.fetchOne(db, sql: "SELECT proposedValue FROM carcass_calibration_candidates") ?? 0
            )
        }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(recordID, "CARCASS-CAL-variabel_pro_korpus")
        XCTAssertEqual(samples, 3)
        XCTAssertEqual(status, "candidate")
        XCTAssertEqual(current, 685, accuracy: 1e-9)
        XCTAssertEqual(proposed, 685 * 1.05, accuracy: 1e-6)
        do {
            try await engine.recordCarcassCorrection(estimateID: estimate.estimateID, targetKey: "bogus", observedNet: 1, reason: .marketPrice, note: "", learn: false)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LearningFailure, .unknownCarcassTarget("bogus"))
        }
        do {
            try await engine.recordCarcassCorrection(estimateID: estimate.estimateID, targetKey: "schub_holz_eur", observedNet: 1, reason: .marketPrice, note: "", learn: false)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LearningFailure, .carcassTargetNotInSession(key: "schub_holz_eur", sessionID: estimate.estimateID))
        }
        do {
            try await engine.recordCarcassCorrection(estimateID: "unknown", targetKey: "fixkosten_sockel", observedNet: 1, reason: .marketPrice, note: "", learn: false)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LearningFailure, .carcassSnapshotMissing("unknown"))
        }
    }

    func testEngineDevicePriceFallsBackToCatalogPrices() async throws {
        let learning = LearningStore(database: try SQLiteStore.inMemory())
        let live = EstimationEngine(anchors: SeedAnchors(), learningStore: learning, articlePrices: FixedPrice(price: 10), devicePrices: FixedPrice(price: 20))
        let fallback = EstimationEngine(anchors: SeedAnchors(), learningStore: learning, articlePrices: FixedPrice(price: nil), devicePrices: FixedPrice(price: 20))
        let none = EstimationEngine(anchors: SeedAnchors(), learningStore: learning)
        let liveValue = await live.devicePrice(term: "x")
        let fallbackValue = await fallback.devicePrice(term: "x")
        let noneValue = await none.devicePrice(term: "x")
        XCTAssertEqual(liveValue, 10)
        XCTAssertEqual(fallbackValue, 20)
        XCTAssertNil(noneValue)
    }

    func testEngineWritesAuditSummariesAsNoticeJSON() async throws {
        let database = try SQLiteStore.inMemory()
        let audit = await MainActor.run { AuditStore(database: database) }
        let engine = EstimationEngine(anchors: SeedAnchors(), learningStore: LearningStore(database: database), auditStore: audit)
        let estimate = try await engine.estimate(projectID: "P7", text: "60cm Unterschrank")
        try await engine.recordAdjustment(estimateID: estimate.estimateID, factor: 0.9, ground: "weil")
        let summaries: [(String, String)] = try await MainActor.run {
            try audit.load()
            return audit.entries.map { ($0.projectID, $0.summary) }
        }
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].0, "P7")
        let notice = try XCTUnwrap(Notice(json: summaries[0].1))
        XCTAssertEqual(notice.key, "calc.audit.adjusted")
        XCTAssertEqual(notice.arguments, ["10", "calc.direction.cheaper", "weil"])
        XCTAssertEqual(EstimationEngine.directionKey(0), "calc.direction.unchanged")
        XCTAssertEqual(EstimationEngine.directionKey(0.4), "calc.direction.unchanged")
        XCTAssertEqual(EstimationEngine.directionKey(-0.4), "calc.direction.unchanged")
        XCTAssertEqual(EstimationEngine.directionKey(0.6), "calc.direction.higher")
        XCTAssertEqual(EstimationEngine.directionKey(-0.6), "calc.direction.cheaper")
    }

    func testIsKitchenDetection() {
        let parser = EstimateRequestParser()
        XCTAssertTrue(EstimationEngine.isKitchen(parser.parse("Küche")))
        XCTAssertTrue(EstimationEngine.isKitchen(parser.parse("4 lfm Küchenzeile")))
        XCTAssertTrue(EstimationEngine.isKitchen(parser.parse("Insel 2 x 1 m")))
        XCTAssertFalse(EstimationEngine.isKitchen(parser.parse("60cm Unterschrank")))
    }
}
