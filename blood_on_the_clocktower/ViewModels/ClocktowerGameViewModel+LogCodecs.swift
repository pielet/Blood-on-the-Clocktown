import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Recorded Log Localization Bridge

    func logTone(forRecordedLog text: String) -> LogTone {
        let decoded = decodedRecordedLog(text)
        if let toneOverride = decoded.toneOverride {
            return toneOverride
        }
        let localizedText = localizedRecordedLog(decoded.text)
        return LogToneClassifier.classify(englishText: decoded.text, chineseText: localizedText)
    }

    func color(forRecordedLog text: String) -> Color {
        color(for: logTone(forRecordedLog: text))
    }

    func localizedRecordedReason(_ reason: String) -> String {
        ClocktowerRecordedLogTextSupport.localizedRecordedReason(reason) { english, chinese in
            ui(english, chinese)
        }
    }

    func localizedRecordedLog(_ rawText: String) -> String {
        let text = decodedRecordedLog(rawText).text
        return ClocktowerRecordedLogTextSupport.localizedRecordedLog(text, context: recordedLogTextContext)
    }

    var recordedLogTextContext: ClocktowerRecordedLogTextSupport.Context {
        ClocktowerRecordedLogTextSupport.Context(
            ui: { english, chinese in
                self.ui(english, chinese)
            },
            localizedRoleNameFromRecordedText: { rawName in
                self.localizedRoleNameFromRecordedText(rawName)
            },
            troubleBrewingRegistrationLogSuffix: { note in
                self.troubleBrewingRegistrationLogSuffix(from: note)
            },
            noOutsiderChoiceID: noOutsiderChoiceID
        )
    }

    func localizedRoleNameFromRecordedText(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedRoleId = decodedNightRoleChoice(from: trimmed).roleId ?? trimmed
        if let role = phaseTemplate.roles.first(where: {
            $0.id == parsedRoleId || $0.name == parsedRoleId || $0.chineseName == parsedRoleId
        }) {
            return localizedRoleName(role)
        }
        return parsedRoleId
    }

    // MARK: - Log Encoding / Decoding

    func encodedRecordedLog(_ text: String, toneOverride: LogTone?) -> String {
        guard let toneOverride else { return text }
        return "\(recordedLogTonePrefix)\(encodedLogTone(toneOverride))|\(text)"
    }

    func decodedRecordedLog(_ text: String) -> (text: String, toneOverride: LogTone?) {
        guard text.hasPrefix(recordedLogTonePrefix) else {
            return (text, nil)
        }

        let payload = String(text.dropFirst(recordedLogTonePrefix.count))
        guard let separatorIndex = payload.firstIndex(of: "|") else {
            return (text, nil)
        }

        let rawTone = String(payload[..<separatorIndex])
        let rawText = String(payload[payload.index(after: separatorIndex)...])
        return (rawText, decodedLogTone(rawTone))
    }

    func encodedLogTone(_ tone: LogTone) -> String {
        switch tone {
        case .primary:
            return "primary"
        case .transfer:
            return "transfer"
        case .poison:
            return "poison"
        case .drunk:
            return "drunk"
        case .noAction:
            return "no-action"
        case .kill:
            return "kill"
        }
    }

    func decodedLogTone(_ rawValue: String) -> LogTone? {
        switch rawValue {
        case "primary":
            return .primary
        case "transfer":
            return .transfer
        case "poison":
            return .poison
        case "drunk":
            return .drunk
        case "no-action":
            return .noAction
        case "kill":
            return .kill
        default:
            return nil
        }
    }

    // MARK: - Night Role Choice Codecs

    func encodedNightRoleChoiceId(roleId: String?, registeringPlayerId: UUID?) -> String {
        guard let roleId else { return noOutsiderChoiceID }
        guard let registeringPlayerId else { return roleId }
        return "\(roleId)\(nightRoleChoiceRegistrationSeparator)\(registeringPlayerId.uuidString)"
    }

    func decodedNightRoleChoice(from choiceId: String) -> (roleId: String?, registeringPlayerId: UUID?) {
        let trimmed = choiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        if trimmed == noOutsiderChoiceID {
            return (nil, nil)
        }
        let parts = trimmed.components(separatedBy: nightRoleChoiceRegistrationSeparator)
        guard let roleId = parts.first, !roleId.isEmpty else { return (nil, nil) }
        let registeringPlayerId = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        return (roleId, registeringPlayerId)
    }

    func troubleBrewingRegistrationLogSuffix(from note: String) -> (english: String, chinese: String) {
        let parsedChoice = decodedNightRoleChoice(from: note)
        guard let shownRoleId = parsedChoice.roleId,
              let registeringPlayerId = parsedChoice.registeringPlayerId,
              let registeringPlayer = playerLookup(by: registeringPlayerId),
              let shownRole = roleTemplate(for: shownRoleId) else {
            return ("", "")
        }

        if let actualRole = roleTemplate(for: registeringPlayer.roleId ?? "") {
            return (
                " \(registeringPlayer.name) (\(actualRole.name)) registered as the \(shownRole.name).",
                " \(registeringPlayer.name)（\(actualRole.chineseName)）登记为 \(shownRole.chineseName)。"
            )
        }

        return (
            " \(registeringPlayer.name) registered as the \(shownRole.name).",
            " \(registeringPlayer.name) 登记为 \(shownRole.chineseName)。"
        )
    }
}
