import Foundation

struct TroubleBrewingInfoSupport {
    struct Message {
        let english: String
        let chinese: String
    }

    struct Context {
        let actorName: String
        let chosenNames: String
        let shownRoleName: String?
        let registrationSuffix: RegistrationSuffix
        let isNoOutsiderResult: Bool
    }

    struct RegistrationSuffix {
        let english: String
        let chinese: String
    }

    static func informationalMessage(
        roleId: String,
        context: Context
    ) -> Message {
        switch roleId {
        case "washerwoman":
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) still needs a Townsfolk role for Washerwoman.",
                    chinese: "\(context.actorName) 还需要为洗衣妇选择一个镇民角色。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) learned the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 得知了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) learned that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 得知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        case "librarian":
            if context.isNoOutsiderResult {
                return Message(
                    english: "\(context.actorName) learned there is no Outsider in play.",
                    chinese: "\(context.actorName) 得知场上没有外来者。"
                )
            }
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) still needs an Outsider role for Librarian.",
                    chinese: "\(context.actorName) 还需要为图书管理员选择一个外来者角色。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) learned the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 得知了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) learned that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 得知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        case "investigator":
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) still needs a Minion role for Investigator.",
                    chinese: "\(context.actorName) 还需要为调查员选择一个爪牙角色。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) learned the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 得知了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) learned that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 得知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        default:
            return Message(english: "", chinese: "")
        }
    }

    static func displayedDrunkInformationalMessage(
        roleId: String,
        context: Context
    ) -> Message {
        switch roleId {
        case "washerwoman":
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. Record a false Washerwoman role result.",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。请记录一个错误的洗衣妇角色结果。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. They were falsely told the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误展示了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) is actually the Drunk. They were falsely told that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误告知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        case "librarian":
            if context.isNoOutsiderResult {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. They were falsely told there is no Outsider in play.",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误告知本局没有外来者。"
                )
            }
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. Record a false Librarian role result.",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。请记录一个错误的图书管理员角色结果。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. They were falsely told the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误展示了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) is actually the Drunk. They were falsely told that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误告知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        case "investigator":
            guard let shownRoleName = context.shownRoleName else {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. Record a false Investigator role result.",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。请记录一个错误的调查员角色结果。"
                )
            }
            if context.chosenNames.isEmpty {
                return Message(
                    english: "\(context.actorName) is actually the Drunk. They were falsely told the \(shownRoleName).\(context.registrationSuffix.english)",
                    chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误展示了 \(shownRoleName)。\(context.registrationSuffix.chinese)"
                )
            }
            return Message(
                english: "\(context.actorName) is actually the Drunk. They were falsely told that one of \(context.chosenNames) is the \(shownRoleName).\(context.registrationSuffix.english)",
                chinese: "\(context.actorName) 的真实身份是酒鬼。说书人向其错误告知 \(context.chosenNames) 之中有一人是 \(shownRoleName)。\(context.registrationSuffix.chinese)"
            )

        default:
            return Message(english: "", chinese: "")
        }
    }
}
