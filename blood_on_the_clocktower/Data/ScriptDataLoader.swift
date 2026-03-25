import Foundation

// MARK: - Public Data Types

struct ExperimentalRoleCatalogData: Codable {
    let roles: [RoleTemplate]
}

struct ExperimentalEditionOverlayData: Codable {
    let roleIds: [String]
    let nightOrderFirstIds: [String]
    let nightOrderStandardIds: [String]
}

struct ScriptManifest: Codable {
    let editions: [ScriptManifestEntry]
}

struct ScriptManifestEntry: Codable, Hashable {
    let id: String
    let fileName: String
    let experimentalOverlayFileName: String?
}

struct ScriptCatalog {
    let manifest: ScriptManifest
    let baseTemplatesById: [String: ScriptTemplate]
    let experimentalRolesById: [String: RoleTemplate]
    let experimentalOverlaysByEditionId: [String: ExperimentalEditionOverlayData]

    var baseTemplates: [ScriptTemplate] {
        manifest.editions.compactMap { baseTemplatesById[$0.id] }
    }

    func baseTemplate(for id: String) -> ScriptTemplate? {
        baseTemplatesById[id]
    }

    func experimentalOverlay(for editionId: String) -> ExperimentalEditionOverlayData? {
        experimentalOverlaysByEditionId[editionId]
    }

    func template(for id: String, includingExperimental: Bool) -> ScriptTemplate? {
        guard let template = baseTemplatesById[id] else { return nil }
        guard includingExperimental, let overlay = experimentalOverlaysByEditionId[id] else {
            return template
        }
        return mergedTemplate(template, with: overlay)
    }

    func roleTemplate(for id: String, templateId: String? = nil, includingExperimental: Bool = true) -> RoleTemplate? {
        if let templateId,
           let template = template(for: templateId, includingExperimental: includingExperimental),
           let role = template.roles.first(where: { $0.id == id }) {
            return role
        }

        if let role = baseTemplates
            .lazy
            .flatMap(\.roles)
            .first(where: { $0.id == id }) {
            return role
        }

        return experimentalRolesById[id]
    }

    private func mergedTemplate(
        _ template: ScriptTemplate,
        with overlay: ExperimentalEditionOverlayData
    ) -> ScriptTemplate {
        let existingRoleIds = Set(template.roles.map(\.id))
        let mergedRoles = template.roles + overlay.roleIds
            .compactMap { experimentalRolesById[$0] }
            .filter { !existingRoleIds.contains($0.id) }

        let mergedFirstNight = template.nightOrderFirst + overlay.nightOrderFirstIds.map {
            NightStepTemplate(id: "experimental-first-\($0)", roleId: $0, condition: .ifRoleInPlay(roleId: $0))
        }
        let mergedStandardNight = template.nightOrderStandard + overlay.nightOrderStandardIds.map {
            NightStepTemplate(id: "experimental-night-\($0)", roleId: $0, condition: .ifRoleInPlay(roleId: $0))
        }

        return ScriptTemplate(
            id: template.id,
            name: template.name,
            chineseName: template.chineseName,
            roles: mergedRoles,
            nightOrderFirst: mergedFirstNight,
            nightOrderStandard: mergedStandardNight
        )
    }
}

// MARK: - Loader

enum ScriptDataLoader {

    static func loadCatalog(bundle: Bundle = .main) -> ScriptCatalog {
        let manifest = loadManifest(bundle: bundle)
        let baseTemplatePairs: [(String, ScriptTemplate)] = manifest.editions.compactMap { entry in
                guard let template = loadScript(named: entry.fileName, from: bundle) else { return nil }
                return (entry.id, template)
            }
        let baseTemplates = Dictionary(uniqueKeysWithValues: baseTemplatePairs)
        let experimentalRoles = Dictionary(
            uniqueKeysWithValues: loadExperimentalRoleCatalog(bundle: bundle).roles.map { ($0.id, $0) }
        )
        let overlayPairs: [(String, ExperimentalEditionOverlayData)] = manifest.editions.compactMap { entry in
                guard let fileName = entry.experimentalOverlayFileName,
                      let overlay = loadExperimentalOverlay(named: fileName, bundle: bundle) else {
                    return nil
                }
                return (entry.id, overlay)
            }
        let overlays = Dictionary(uniqueKeysWithValues: overlayPairs)

        return ScriptCatalog(
            manifest: manifest,
            baseTemplatesById: baseTemplates,
            experimentalRolesById: experimentalRoles,
            experimentalOverlaysByEditionId: overlays
        )
    }

    static func loadBaseScripts(bundle: Bundle = .main) -> [ScriptTemplate] {
        loadCatalog(bundle: bundle).baseTemplates
    }

    // MARK: - Private

    private static func loadManifest(bundle: Bundle) -> ScriptManifest {
        loadJSON(named: "script_manifest", bundle: bundle)
        ?? ScriptManifest(
            editions: [
                ScriptManifestEntry(
                    id: "trouble-brewing",
                    fileName: "trouble_brewing",
                    experimentalOverlayFileName: "experimental_trouble_brewing"
                ),
                ScriptManifestEntry(
                    id: "bad-moon-rising",
                    fileName: "bad_moon_rising",
                    experimentalOverlayFileName: "experimental_bad_moon_rising"
                ),
                ScriptManifestEntry(
                    id: "sects-and-violets",
                    fileName: "sects_and_violets",
                    experimentalOverlayFileName: "experimental_sects_and_violets"
                )
            ]
        )
    }

    private static func loadExperimentalRoleCatalog(bundle: Bundle) -> ExperimentalRoleCatalogData {
        loadJSON(named: "experimental_roles", bundle: bundle)
        ?? ExperimentalRoleCatalogData(roles: [])
    }

    private static func loadExperimentalOverlay(
        named fileName: String,
        bundle: Bundle
    ) -> ExperimentalEditionOverlayData? {
        loadJSON(named: fileName, bundle: bundle)
    }

    private static func loadScript(named fileName: String, from bundle: Bundle) -> ScriptTemplate? {
        let script: ScriptJSON? = loadJSON(named: fileName, bundle: bundle)
        return script?.toScriptTemplate()
    }

    private static func loadJSON<T: Decodable>(named fileName: String, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Intermediate Decode Types

private struct ScriptJSON: Codable {
    let id: String
    let name: String
    let chineseName: String
    let roles: [RoleTemplate]
    let nightOrderFirst: [NightStepJSON]
    let nightOrderStandard: [NightStepJSON]

    func toScriptTemplate() -> ScriptTemplate {
        ScriptTemplate(
            id: id,
            name: name,
            chineseName: chineseName,
            roles: roles,
            nightOrderFirst: nightOrderFirst.map(\.toNightStep),
            nightOrderStandard: nightOrderStandard.map(\.toNightStep)
        )
    }
}

private struct NightStepJSON: Codable {
    let id: String
    let roleId: String
    let condition: String
    let conditionRoleId: String?

    var toNightStep: NightStepTemplate {
        let cond: NightStepCondition
        switch condition {
        case "always":
            cond = .always
        case "ifRoleInPlay":
            cond = .ifRoleInPlay(roleId: conditionRoleId ?? roleId)
        case "ifExecutionHappenedToday":
            cond = .ifExecutionHappenedToday
        case "ifActorDiedTonight":
            cond = .ifActorDiedTonight(roleId: conditionRoleId ?? roleId)
        default:
            cond = .always
        }
        return NightStepTemplate(id: id, roleId: roleId, condition: cond)
    }
}

// MARK: - RoleTemplate Codable Conformance

extension RoleTemplate: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, chineseName, team, summary, chineseSummary
        case detail, chineseDetail, icon
        case firstNight, otherNights, otherNightsExceptFirst
        case targetCountFirstNight, targetCountNight, needsNightResultInput
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        chineseName = try c.decodeIfPresent(String.self, forKey: .chineseName) ?? name
        team = try c.decode(RoleTeam.self, forKey: .team)
        summary = try c.decode(String.self, forKey: .summary)
        chineseSummary = try c.decodeIfPresent(String.self, forKey: .chineseSummary) ?? summary
        detail = try c.decode(String.self, forKey: .detail)
        chineseDetail = try c.decodeIfPresent(String.self, forKey: .chineseDetail) ?? detail
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "person.fill.questionmark"
        firstNight = try c.decodeIfPresent(Bool.self, forKey: .firstNight) ?? false
        otherNights = try c.decodeIfPresent(Bool.self, forKey: .otherNights) ?? false
        otherNightsExceptFirst = try c.decodeIfPresent(Bool.self, forKey: .otherNightsExceptFirst) ?? false
        targetCountFirstNight = try c.decodeIfPresent(Int.self, forKey: .targetCountFirstNight) ?? 0
        targetCountNight = try c.decodeIfPresent(Int.self, forKey: .targetCountNight) ?? 0
        needsNightResultInput = try c.decodeIfPresent(Bool.self, forKey: .needsNightResultInput) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(chineseName, forKey: .chineseName)
        try c.encode(team, forKey: .team)
        try c.encode(summary, forKey: .summary)
        try c.encode(chineseSummary, forKey: .chineseSummary)
        try c.encode(detail, forKey: .detail)
        try c.encode(chineseDetail, forKey: .chineseDetail)
        try c.encode(icon, forKey: .icon)
        try c.encode(firstNight, forKey: .firstNight)
        try c.encode(otherNights, forKey: .otherNights)
        try c.encode(otherNightsExceptFirst, forKey: .otherNightsExceptFirst)
        try c.encode(targetCountFirstNight, forKey: .targetCountFirstNight)
        try c.encode(targetCountNight, forKey: .targetCountNight)
        try c.encode(needsNightResultInput, forKey: .needsNightResultInput)
    }
}

// MARK: - Global Convenience (used by tests and some helpers)

func roleTemplate(for id: String) -> RoleTemplate? {
    ScriptDataLoader.loadCatalog().roleTemplate(for: id)
}
