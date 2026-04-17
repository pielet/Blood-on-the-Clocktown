import Foundation

struct ClocktowerRecordedLogTextSupport {
    struct Context {
        let ui: (String, String) -> String
        let localizedRoleNameFromRecordedText: (String) -> String
        let troubleBrewingRegistrationLogSuffix: (String) -> (english: String, chinese: String)
        let noOutsiderChoiceID: String
    }

    static func localizedRecordedReason(
        _ reason: String,
        ui: (String, String) -> String
    ) -> String {
        switch reason {
        case "Imp suicide", "小恶魔自杀":
            return ui("Imp suicide", "小恶魔自杀")
        case "Killed by night action", "夜间技能击杀":
            return ui("Killed by night action", "夜间技能击杀")
        case "Slayer shot", "猎手击杀":
            return ui("Slayer shot", "猎手击杀")
        case "Lycanthrope attack", "狼人击杀":
            return ui("Lycanthrope attack", "狼人击杀")
        case "Lleech host died", "利奇宿主死亡":
            return ui("Lleech host died", "利奇宿主死亡")
        case "Executed", "处决":
            return ui("Executed", "处决")
        case "Virgin first nomination", "贞洁者首次被提名":
            return ui("Virgin first nomination", "贞洁者首次被提名")
        default:
            return reason
        }
    }

    static func localizedRecordedLog(
        _ text: String,
        context: Context
    ) -> String {
        let ui = context.ui

        if let structured = localizedStructuredRoleAction(from: text, context: context) {
            return structured
        }

        let exactPairs = [
            ("Became the Demon.", "转变为恶魔。"),
            ("Replacement selected after the Imp died.", "在小恶魔死亡后被选为替代恶魔。"),
            ("Spent the dead vote during day voting.", "在白天投票中用掉了幽灵票。"),
            ("Actually the Drunk. Used a fake Slayer shot.", "真实身份是酒鬼。使用了一次假的猎手射击。"),
            ("Poisoned tonight.", "今夜中毒。"),
            ("Protected this night by the Monk.", "今夜受到僧侣保护。"),
            ("Was chosen as the Butler's master.", "被选为管家的主人。"),
            ("Died as the Imp.", "以小恶魔身份死亡。"),
            ("Returned to life by the Professor.", "被教授复活。"),
            ("The Nightwatchman confirmed themselves to you.", "守夜人向你确认了自己的身份。"),
            ("Learned that a Widow is in play.", "得知本局有寡妇在场。"),
            ("Became Riot.", "转变为暴乱。"),
            ("Survived the first death as the Fool.", "以愚者身份免除了第一次死亡。"),
            ("Survived the first death as the Zombuul.", "以僵怖身份免除了第一次死亡。")
        ]

        if let pair = exactPairs.first(where: { $0.0 == text || $0.1 == text }) {
            return ui(pair.0, pair.1)
        }

        if let delta = text.capture(prefix: "Vote modifier changed by ", suffix: ".") {
            return ui("Vote modifier changed by \(delta).", "投票修正值变化 \(delta)。")
        }
        if let delta = text.capture(prefix: "投票修正值变化 ", suffix: "。") {
            return ui("Vote modifier changed by \(delta).", "投票修正值变化 \(delta)。")
        }

        if let reason = text.capture(prefix: "Died: ", suffix: "") {
            let localizedReason = localizedRecordedReason(reason, ui: ui)
            return ui("Died: \(localizedReason)", "死亡：\(localizedReason)")
        }
        if let reason = text.capture(prefix: "死亡：", suffix: "") {
            let localizedReason = localizedRecordedReason(reason, ui: ui)
            return ui("Died: \(localizedReason)", "死亡：\(localizedReason)")
        }

        if let (actor, roleName) = text.captureTwo(before: " skipped ", after: " because of poison.") {
            let localizedRole = context.localizedRoleNameFromRecordedText(roleName)
            return ui("\(actor) skipped \(localizedRole) because of poison.", "\(actor) 因中毒跳过了 \(localizedRole)。")
        }
        if let (actor, roleName) = text.captureTwo(before: " 因中毒跳过了 ", after: "。") {
            let localizedRole = context.localizedRoleNameFromRecordedText(roleName)
            return ui("\(actor) skipped \(localizedRole) because of poison.", "\(actor) 因中毒跳过了 \(localizedRole)。")
        }

        if let name = text.capture(prefix: "Confirmed to ", suffix: " as the Nightwatchman.") {
            return ui("Confirmed to \(name) as the Nightwatchman.", "向 \(name) 确认了自己是守夜人。")
        }
        if let name = text.capture(prefix: "向 ", suffix: " 确认了自己是守夜人。") {
            return ui("Confirmed to \(name) as the Nightwatchman.", "向 \(name) 确认了自己是守夜人。")
        }

        if let name = text.capture(prefix: "Learned that ", suffix: " is evil.") {
            return ui("Learned that \(name) is evil.", "得知 \(name) 是邪恶玩家。")
        }
        if let name = text.capture(prefix: "得知 ", suffix: " 是邪恶玩家。") {
            return ui("Learned that \(name) is evil.", "得知 \(name) 是邪恶玩家。")
        }

        if let payload = text.capture(prefix: "Learned a ", suffix: "."),
           let splitIndex = payload.firstIndex(of: ":") {
            let teamName = String(payload[..<splitIndex]).trimmingCharacters(in: .whitespaces)
            let learnedPlayerName = String(payload[payload.index(after: splitIndex)...]).trimmingCharacters(in: .whitespaces)
            let localizedTeam = localizedRecordedTeamName(teamName, ui: ui)
            return ui("Learned a \(localizedTeam): \(learnedPlayerName).", "得知一名\(localizedTeam)：\(learnedPlayerName)。")
        }
        if let payload = text.capture(prefix: "得知一名", suffix: "。"),
           let splitIndex = payload.firstIndex(of: "：") {
            let teamName = String(payload[..<splitIndex])
            let learnedPlayerName = String(payload[payload.index(after: splitIndex)...])
            let localizedTeam = localizedRecordedTeamName(teamName, ui: ui)
            return ui("Learned a \(localizedTeam): \(learnedPlayerName).", "得知一名\(localizedTeam)：\(learnedPlayerName)。")
        }

        if let payload = text.capture(prefix: "Village Idiot learned ", suffix: "."),
           let range = payload.range(of: " is ") {
            let targetName = String(payload[..<range.lowerBound])
            let rawAlignment = String(payload[range.upperBound...])
            let localizedAlignment = localizedRecordedAlignment(rawAlignment, ui: ui)
            return ui("Village Idiot learned \(targetName) is \(localizedAlignment).", "村中傻子得知 \(targetName) 是\(localizedAlignment)阵营。")
        }
        if let payload = text.capture(prefix: "村中傻子得知 ", suffix: "。"),
           let range = payload.range(of: " 是") {
            let targetName = String(payload[..<range.lowerBound])
            let rawAlignment = String(payload[range.upperBound...]).replacingOccurrences(of: "阵营", with: "")
            let localizedAlignment = localizedRecordedAlignment(rawAlignment, ui: ui)
            return ui("Village Idiot learned \(targetName) is \(localizedAlignment).", "村中傻子得知 \(targetName) 是\(localizedAlignment)阵营。")
        }

        if let name = text.capture(prefix: "Used the Slayer shot on ", suffix: " successfully.") {
            return ui("Used the Slayer shot on \(name) successfully.", "成功对 \(name) 发动了猎手技能。")
        }
        if let name = text.capture(prefix: "成功对 ", suffix: " 发动了猎手技能。") {
            return ui("Used the Slayer shot on \(name) successfully.", "成功对 \(name) 发动了猎手技能。")
        }
        if let name = text.capture(prefix: "Used the Slayer shot on ", suffix: " unsuccessfully.") {
            return ui("Used the Slayer shot on \(name) unsuccessfully.", "已对 \(name) 发动猎手技能，但未成功。")
        }
        if let name = text.capture(prefix: "已对 ", suffix: " 发动猎手技能，但未成功。") {
            return ui("Used the Slayer shot on \(name) unsuccessfully.", "已对 \(name) 发动猎手技能，但未成功。")
        }
        if let name = text.capture(prefix: "Actually the Drunk. Used a fake Slayer shot on ", suffix: ".") {
            return ui("Actually the Drunk. Used a fake Slayer shot on \(name).", "真实身份是酒鬼。对 \(name) 使用了一次假的猎手射击。")
        }
        if let name = text.capture(prefix: "真实身份是酒鬼。对 ", suffix: " 使用了一次假的猎手射击。") {
            return ui("Actually the Drunk. Used a fake Slayer shot on \(name).", "真实身份是酒鬼。对 \(name) 使用了一次假的猎手射击。")
        }

        if let (actor, payload) = text.captureTwo(before: " used ", after: "") {
            return localizedUsedRoleLog(actor: actor, payload: payload, context: context)
        }
        if let (actor, payload) = text.captureTwo(before: " 使用了 ", after: "") {
            return localizedUsedRoleLog(actor: actor, payload: payload, context: context)
        }

        return text
    }

    private static func localizedUsedRoleLog(
        actor: String,
        payload: String,
        context: Context
    ) -> String {
        let ui = context.ui
        let noteParts = payload.components(separatedBy: " | ")
        let mainPart = noteParts.first ?? payload
        let note = noteParts.count > 1 ? noteParts.dropFirst().joined(separator: " | ") : ""
        let targetParts = mainPart.components(separatedBy: " -> ")
        let rolePart = targetParts.first ?? mainPart
        let targetText = targetParts.count > 1 ? targetParts.dropFirst().joined(separator: " -> ") : ""
        let localizedRole = context.localizedRoleNameFromRecordedText(rolePart)
        let targetSuffix = targetText.isEmpty ? "" : " -> \(targetText)"
        let noteSuffix = note.isEmpty ? "" : " | \(note)"
        return ui(
            "\(actor) used \(localizedRole)\(targetSuffix)\(noteSuffix)",
            "\(actor) 使用了 \(localizedRole)\(targetSuffix)\(noteSuffix)"
        )
    }

    private static func localizedRecordedTeamName(
        _ rawName: String,
        ui: (String, String) -> String
    ) -> String {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "townsfolk", "镇民":
            return ui("Townsfolk", "镇民")
        case "outsider", "外来者":
            return ui("Outsider", "外来者")
        case "minion", "爪牙":
            return ui("Minion", "爪牙")
        case "demon", "恶魔":
            return ui("Demon", "恶魔")
        case "traveller", "旅人":
            return ui("Traveller", "旅人")
        default:
            return rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func localizedRecordedAlignment(
        _ rawValue: String,
        ui: (String, String) -> String
    ) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "good", "善良":
            return ui("good", "善良")
        case "evil", "邪恶":
            return ui("evil", "邪恶")
        default:
            return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func localizedStructuredRoleAction(
        from text: String,
        context: Context
    ) -> String? {
        let ui = context.ui
        guard text.hasPrefix(ClocktowerGameViewModel.roleActionRecordPrefix) else { return nil }
        let payload = String(text.dropFirst(ClocktowerGameViewModel.roleActionRecordPrefix.count))
        let parts = payload.components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }
        let key = parts[0]
        let actor = parts[1]
        let targetText = parts[2]
        let note = parts[3]

        switch key {
        case "imp-bluffs":
            let roleIds = note.split(separator: ",").map(String.init)
            let bluffNames = roleIds.map(context.localizedRoleNameFromRecordedText).joined(separator: ", ")
            return ui("Shown Imp bluffs: \(bluffNames).", "展示给小恶魔的可伪装角色：\(bluffNames)。")
        case "acrobat-track":
            return ui("\(actor) chose \(targetText) for Acrobat.", "\(actor) 选择 \(targetText) 作为杂技演员目标。")
        case "alchemist-grant":
            return note.isEmpty ? ui("\(actor) used Alchemist.", "\(actor) 使用了炼金术士能力。") : ui("\(actor) gained the \(context.localizedRoleNameFromRecordedText(note)) ability as Alchemist.", "\(actor) 作为炼金术士获得了 \(context.localizedRoleNameFromRecordedText(note)) 能力。")
        case "steward-info":
            return ui("\(actor) learned 1 good player.", "\(actor) 得知了 1 名善良玩家。")
        case "noble-info":
            return ui("\(actor) learned 3 players with exactly 1 evil.", "\(actor) 得知了 3 名玩家，其中恰有 1 名邪恶。")
        case "knight-info":
            return ui("\(actor) learned 2 players that are not the Demon.", "\(actor) 得知了 2 名不是恶魔的玩家。")
        case "shugenja-info":
            return ui("\(actor) learned which direction the nearest evil lies.", "\(actor) 得知了最近邪恶的大致方向。")
        case "pixie-info":
            return ui("\(actor) learned an in-play Townsfolk.", "\(actor) 得知了一名在场镇民。")
        case "high-priestess-info":
            return ui("\(actor) was guided to a player by High Priestess.", "\(actor) 以女祭司能力被引导到一名玩家。")
        case "king-info":
            return ui("\(actor) learned an alive character.", "\(actor) 得知了一个存活角色。")
        case "choirboy-info":
            return ui("\(actor) learned the Demon because the King died.", "\(actor) 因国王死亡而得知了恶魔。")
        case "boffin-grant":
            return note.isEmpty ? ui("\(actor) used Boffin.", "\(actor) 使用了博芬能力。") : ui("\(actor) granted the Demon the \(context.localizedRoleNameFromRecordedText(note)) ability.", "\(actor) 让恶魔获得了 \(context.localizedRoleNameFromRecordedText(note)) 能力。")
        case "grandmother-link":
            return ui("\(actor) learned that \(targetText) is their good player.", "\(actor) 得知 \(targetText) 是自己的祖母目标。")
        case "sailor-drink":
            return ui("\(actor) chose \(targetText) for the Sailor ability.", "\(actor) 用水手能力选择了 \(targetText)。")
        case "chambermaid-check":
            return ui("\(actor) compared whether \(targetText) woke tonight.", "\(actor) 查看 \(targetText) 今晚是否醒来。")
        case "exorcist-target":
            return ui("\(actor) chose \(targetText) for the Exorcist check.", "\(actor) 选择 \(targetText) 作为驱魔目标。")
        case "innkeeper-protect":
            return ui("\(actor) protected \(targetText) as the Innkeeper.", "\(actor) 以店主能力保护了 \(targetText)。")
        case "gambler-guess":
            let localizedGuess = context.localizedRoleNameFromRecordedText(note)
            return note.isEmpty
                ? ui("\(actor) gambled on \(targetText).", "\(actor) 对 \(targetText) 发动了赌徒能力。")
                : ui("\(actor) guessed \(localizedGuess) for \(targetText).", "\(actor) 猜测 \(targetText) 是 \(localizedGuess)。")
        case "courtier-drunk":
            let localizedChoice = context.localizedRoleNameFromRecordedText(note)
            return ui("\(actor) chose \(localizedChoice) for the Courtier ability.", "\(actor) 用朝臣能力选择了 \(localizedChoice)。")
        case "professor-revive":
            return ui("\(actor) chose \(targetText) for resurrection.", "\(actor) 选择复活 \(targetText)。")
        case "devils-advocate-protect":
            return ui("\(actor) protected \(targetText) from tomorrow's execution.", "\(actor) 保护 \(targetText) 免于明日处决死亡。")
        case "cultleader-align":
            return ui("\(actor) resolved Cult Leader alignment.", "\(actor) 结算了邪教领袖阵营。")
        case "huntsman-check":
            return ui("\(actor) chose \(targetText) for Huntsman.", "\(actor) 选择 \(targetText) 作为猎人目标。")
        case "witch-curse":
            return ui("\(actor) cursed \(targetText).", "\(actor) 诅咒了 \(targetText)。")
        case "assassin-attack":
            return ui("\(actor) targeted \(targetText) with the Assassin ability.", "\(actor) 用刺客能力指定了 \(targetText)。")
        case "fearmonger-target":
            return ui("\(actor) chose \(targetText) as the Fearmonger target.", "\(actor) 选择 \(targetText) 作为恐惧贩子的目标。")
        case "godfather-kill":
            return ui("\(actor) chose \(targetText) for the Godfather kill.", "\(actor) 选择 \(targetText) 作为教父夜杀目标。")
        case "godfather-none":
            return ui("\(actor) had no Godfather kill tonight.", "\(actor) 今夜教父没有额外击杀。")
        case "nightwatchman-confirm":
            return ui("\(actor) confirmed to \(targetText) as the Nightwatchman.", "\(actor) 向 \(targetText) 确认了自己是守夜人。")
        case "lunatic-fake-kill":
            return ui("\(actor) chose \(targetText) as a fake Demon target.", "\(actor) 选择 \(targetText) 作为假恶魔目标。")
        case "bountyhunter-info":
            return ui("\(actor) learned another evil player.", "\(actor) 得知了另一名邪恶玩家。")
        case "balloonist-info":
            return ui("\(actor) learned a player of a new character type.", "\(actor) 得知了一名不同角色类型的玩家。")
        case "general-info":
            return ui("\(actor) received the General result.", "\(actor) 收到了将军结果。")
        case "mezepheles-word":
            return note.isEmpty ? ui("\(actor) set a Mezepheles word.", "\(actor) 设定了梅泽菲勒斯单词。") : ui("\(actor) set the Mezepheles word: \(note).", "\(actor) 设定了梅泽菲勒斯单词：\(note)。")
        case "organgrinder-secret":
            return ui("\(actor) resolved Organ Grinder secrecy.", "\(actor) 结算了风琴师秘密投票。")
        case "villageidiot-check":
            return ui("\(actor) checked \(targetText)'s alignment.", "\(actor) 查看了 \(targetText) 的阵营。")
        case "poisoner-poison":
            return ui("\(actor) poisoned \(targetText).", "\(actor) 使 \(targetText) 中毒。")
        case "widow-poison":
            return ui("\(actor) chose \(targetText) as the Widow poison target.", "\(actor) 选择 \(targetText) 作为寡妇的投毒目标。")
        case "monk-protect":
            return ui("\(actor) protected \(targetText).", "\(actor) 保护了 \(targetText)。")
        case "butler-master":
            return ui("\(actor) chose \(targetText) as master.", "\(actor) 选择 \(targetText) 作为主人。")
        case "imp-kill":
            return ui("\(actor) chose \(targetText) for the Imp kill.", "\(actor) 选择 \(targetText) 作为小恶魔夜杀目标。")
        case "imp-suicide":
            return ui("\(actor) chose self for Imp suicide.", "\(actor) 选择自己进行小恶魔自杀。")
        case "lleech-host":
            return ui("\(actor) chose \(targetText) as host.", "\(actor) 选择 \(targetText) 作为宿主。")
        case "lleech-kill":
            return ui("\(actor) chose \(targetText) for the Lleech kill.", "\(actor) 选择 \(targetText) 作为利奇夜杀目标。")
        case "lycanthrope-attack":
            return ui("\(actor) targeted \(targetText) with the Lycanthrope ability.", "\(actor) 用狼人能力指定了 \(targetText)。")
        case "preacher-choose":
            return ui("\(actor) preached to \(targetText).", "\(actor) 向 \(targetText) 布道。")
        case "ravenkeeper-check":
            return ui("\(actor) inspected \(targetText) as the Ravenkeeper.", "\(actor) 作为守鸦人查看了 \(targetText)。")
        case "undertaker-info":
            if targetText.isEmpty || note.isEmpty {
                return ui("\(actor) received the Undertaker result.", "\(actor) 收到了送葬者结果。")
            }
            let undertakerRole = context.localizedRoleNameFromRecordedText(note)
            return ui(
                "\(actor) learned that \(targetText) was the \(undertakerRole).",
                "\(actor) 得知 \(targetText) 的真实角色是 \(undertakerRole)。"
            )
        case "oracle-info":
            return ui("\(actor) received the Oracle result.", "\(actor) 收到了神谕者结果。")
        case "flowergirl-info":
            return ui("\(actor) received the Flowergirl result.", "\(actor) 收到了卖花女结果。")
        case "town-crier-info":
            return ui("\(actor) received the Town Crier result.", "\(actor) 收到了传令官结果。")
        case "seamstress-check":
            return ui("\(actor) compared \(targetText).", "\(actor) 比较了 \(targetText) 的阵营。")
        case "juggler-info":
            return ui("\(actor) received the Juggler result.", "\(actor) 收到了杂耍演员结果。")
        case "fortuneteller-check":
            return ui("\(actor) checked \(targetText) as the Fortune Teller.", "\(actor) 作为占卜师查看了 \(targetText)。")
        case "empath-info":
            return note.isEmpty ? ui("\(actor) received the Empath result.", "\(actor) 收到了共情者结果。") : ui("\(actor) received the Empath result: \(note)", "\(actor) 收到了共情者结果：\(note)")
        case "chef-info":
            return note.isEmpty ? ui("\(actor) received the Chef result.", "\(actor) 收到了厨师结果。") : ui("\(actor) received the Chef result: \(note)", "\(actor) 收到了厨师结果：\(note)")
        case "washerwoman-info":
            let washerwomanRole = context.localizedRoleNameFromRecordedText(note)
            let registrationSuffix = context.troubleBrewingRegistrationLogSuffix(note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(washerwomanRole).\(registrationSuffix.english)", "\(actor) 得知了 \(washerwomanRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(washerwomanRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(washerwomanRole)。\(registrationSuffix.chinese)")
        case "librarian-info":
            if note == context.noOutsiderChoiceID {
                return ui("\(actor) learned there is no Outsider in play.", "\(actor) 得知场上没有外来者。")
            }
            let librarianRole = context.localizedRoleNameFromRecordedText(note)
            let registrationSuffix = context.troubleBrewingRegistrationLogSuffix(note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(librarianRole).\(registrationSuffix.english)", "\(actor) 得知了 \(librarianRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(librarianRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(librarianRole)。\(registrationSuffix.chinese)")
        case "investigator-info":
            let investigatorRole = context.localizedRoleNameFromRecordedText(note)
            let registrationSuffix = context.troubleBrewingRegistrationLogSuffix(note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(investigatorRole).\(registrationSuffix.english)", "\(actor) 得知了 \(investigatorRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(investigatorRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(investigatorRole)。\(registrationSuffix.chinese)")
        case "first-night-info":
            return note.isEmpty ? ui("\(actor) received a first-night information result.", "\(actor) 收到了首夜信息结果。") : ui("\(actor) received a first-night information result: \(note)", "\(actor) 收到了首夜信息结果：\(note)")
        case "spy-grimoire":
            return ui("\(actor) checked the Grimoire.", "\(actor) 查看了魔典。")
        case "pukka-poison":
            return ui("\(actor) poisoned \(targetText) as Pukka.", "\(actor) 以普卡之力毒了 \(targetText)。")
        case "alhadikhia-choice":
            return ui("\(actor) chose \(targetText) for Al-Hadikhia.", "\(actor) 为阿尔哈迪基亚选择了 \(targetText)。")
        case "shabaloth-kill":
            return ui("\(actor) chose \(targetText) for the Shabaloth kill.", "\(actor) 选择 \(targetText) 作为沙巴洛斯夜杀目标。")
        case "legion-kill":
            return ui("\(actor) resolved Legion on \(targetText).", "\(actor) 对 \(targetText) 结算了军团能力。")
        case "lilmonsta-night":
            return ui("\(actor) resolved Lil' Monsta. \(note)", "\(actor) 结算了小怪物。\(note)")
        case "po-kill":
            return ui("\(actor) chose \(targetText) for the Po kill.", "\(actor) 选择 \(targetText) 作为波的夜杀目标。")
        case "po-charge":
            return ui("\(actor) skipped the kill to charge Po.", "\(actor) 放弃击杀，为波蓄力。")
        case "snake-charmer-check":
            return ui("\(actor) charmed \(targetText).", "\(actor) 对 \(targetText) 发动了驯蛇。")
        case "fang-gu-jump":
            return ui("\(actor) jumped to \(targetText) as Fang Gu.", "\(actor) 将方固转移给了 \(targetText)。")
        case "fang-gu-kill":
            return ui("\(actor) chose \(targetText) for the Fang Gu kill.", "\(actor) 选择 \(targetText) 作为方固夜杀目标。")
        case "vigormortis-kill":
            return ui("\(actor) chose \(targetText) for the Vigormortis kill.", "\(actor) 选择 \(targetText) 作为维戈莫提斯夜杀目标。")
        case "no-dashii-kill":
            return ui("\(actor) chose \(targetText) for the No Dashii kill.", "\(actor) 选择 \(targetText) 作为诺达希夜杀目标。")
        case "lordoftyphon-kill":
            return ui("\(actor) chose \(targetText) for the Lord of Typhon kill.", "\(actor) 选择 \(targetText) 作为提丰之主夜杀目标。")
        case "ojo-guess":
            return note.isEmpty ? ui("\(actor) used Ojo.", "\(actor) 发动了奥霍能力。") : ui("\(actor) chose \(note) for Ojo.", "\(actor) 为奥霍选择了 \(note)。")
        case "yaggababble-phrase":
            return note.isEmpty ? ui("\(actor) recorded a Yaggababble phrase.", "\(actor) 记录了一条亚嘎巴布尔短语。") : ui("\(actor) recorded the Yaggababble phrase: \(note).", "\(actor) 记录了亚嘎巴布尔短语：\(note)。")
        case "zombuul-kill":
            return ui("\(actor) chose \(targetText) for the Zombuul kill.", "\(actor) 选择 \(targetText) 作为僵怖夜杀目标。")
        case "zombuul-none":
            return ui("\(actor) had no Zombuul kill tonight.", "\(actor) 今夜没有僵怖击杀。")
        case "pit-hag-transform":
            return note.isEmpty ? ui("\(actor) transformed \(targetText).", "\(actor) 变形了 \(targetText)。") : ui("\(actor) transformed \(targetText) into \(note).", "\(actor) 将 \(targetText) 变为 \(note)。")
        case "evil-twin-link":
            return ui("\(actor) checked the Evil Twin link.", "\(actor) 结算了邪恶双子连接。")
        case "engineer-change":
            return note.isEmpty ? ui("\(actor) used Engineer.", "\(actor) 使用了工程师能力。") : ui("\(actor) changed the evil roles to \(note).", "\(actor) 将邪恶角色改为 \(note)。")
        case "summoner-create":
            return note.isEmpty ? ui("\(actor) used Summoner on \(targetText).", "\(actor) 对 \(targetText) 使用了召唤师能力。") : ui("\(actor) summoned \(targetText) as \(context.localizedRoleNameFromRecordedText(note)).", "\(actor) 将 \(targetText) 召唤为 \(context.localizedRoleNameFromRecordedText(note))。")
        case "wizard-wish":
            return note.isEmpty ? ui("\(actor) made a Wizard wish.", "\(actor) 许下了巫师愿望。") : ui("\(actor) made the Wizard wish: \(note).", "\(actor) 许下了巫师愿望：\(note)。")
        case "xaan-night":
            return ui("\(actor) marked the Xaan poison night.", "\(actor) 标记了夏安投毒之夜。")
        case "scarletwoman-check":
            return ui("\(actor) checked Scarlet Woman demon replacement effects.", "\(actor) 结算了红唇女郎的恶魔替换效果。")
        case "dreamer-info":
            return targetText.isEmpty
                ? ui("\(actor) used Dreamer ability.", "\(actor) 使用了梦想家能力。")
                : ui("\(actor) chose \(targetText). Shown: \(note).", "\(actor) 选择了 \(targetText)。展示：\(note)。")
        case "mathematician-info":
            return ui("\(actor) learned the number: \(note.isEmpty ? "0" : note).", "\(actor) 得知数字：\(note.isEmpty ? "0" : note)。")
        case "vortox-kill":
            return targetText.isEmpty
                ? ui("\(actor) had no Vortox kill.", "\(actor) 今夜没有沃托克斯击杀。")
                : ui("\(actor) chose \(targetText) for Vortox kill.", "\(actor) 选择 \(targetText) 作为沃托克斯夜杀目标。")
        default:
            return ui("\(actor) used an ability.", "\(actor) 发动了一次能力。")
        }
    }
}

private extension String {
    func capture(prefix: String, suffix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        let remainder = String(dropFirst(prefix.count))
        if suffix.isEmpty {
            return remainder
        }
        guard remainder.hasSuffix(suffix) else { return nil }
        return String(remainder.dropLast(suffix.count))
    }

    func captureTwo(before separator: String, after suffix: String) -> (String, String)? {
        guard let range = range(of: separator) else { return nil }
        let left = String(self[..<range.lowerBound])
        let right = String(self[range.upperBound...])
        if suffix.isEmpty {
            return (left, right)
        }
        guard right.hasSuffix(suffix) else { return nil }
        return (left, String(right.dropLast(suffix.count)))
    }
}
