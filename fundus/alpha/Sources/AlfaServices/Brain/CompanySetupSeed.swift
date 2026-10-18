import Foundation
import AlfaKit
import MykilosKalkulationsCore

public struct CompanySetupSeed: Codable, Sendable {
    public var teamRoster: [TeamMember]
    public var channelInitials: [String]
    public var workshopFactors: [String: Double]

    public static func load() -> CompanySetupSeed? {
        guard let url = StudioBrain.sichereRessourcenURL(name: "company_setup_seed", ext: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(CompanySetupSeed.self, from: data) else {
            MykLog.lifecycle.error("company_setup_seed.json: unreadable")
            return nil
        }
        return seed
    }

    public static func applyIfNeeded() {
        guard TeamRoster.isConfigured == false || WorkshopFactors.isConfigured == false
                || ChannelInitials.isConfigured == false,
              let seed = load() else { return }
        if TeamRoster.isConfigured == false { TeamRoster.save(seed.teamRoster) }
        if WorkshopFactors.isConfigured == false { WorkshopFactors.save(seed.workshopFactors) }
        if ChannelInitials.isConfigured == false { ChannelInitials.save(seed.channelInitials) }
    }
}
