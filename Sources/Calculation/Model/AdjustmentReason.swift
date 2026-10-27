enum AdjustmentReason: String, CaseIterable, Identifiable, Sendable {
    case materialUnderestimated = "material_underestimated"
    case executionComplexity = "execution_complexity"
    case supplierLevel = "supplier_level"
    case marketPrice = "market_price"
    case logistics
    case gutFeeling = "gut_feeling"
    case realOfferReceived = "real_offer_received"
    case finalInvoiceReceived = "final_invoice_received"
    case correctionError = "correction_error"

    var id: String { rawValue }

    var localizationKey: String { "calc.reason.\(rawValue)" }

    var weight: Double {
        switch self {
        case .finalInvoiceReceived: 2.0
        case .realOfferReceived: 1.6
        case .gutFeeling: 0.6
        case .correctionError: 0.25
        default: 1.0
        }
    }
}
