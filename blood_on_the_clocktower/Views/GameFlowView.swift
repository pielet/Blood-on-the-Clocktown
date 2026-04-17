import SwiftUI

struct GameFlowView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel
    @State private var manualNote = ""
    @State private var lastPassiveInfoSuggestedNote: String?
    @State private var artistNote = ""
    @State private var fishermanNote = ""
    @State private var amnesiacNote = ""
    @State private var savantNote = ""
    @State private var gossipNote = ""
    @State private var jugglerNote = ""
    @State private var alsaahirNote = ""
    @State private var wizardNote = ""
    @State private var selectedMoonchildTargetId: UUID?
    @State private var selectedPsychopathTargetId: UUID?
    @State private var expandedPlayerIDs: Set<UUID> = []

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    storytellerPanel

                    if game.phase == .day {
                        dayVotingPanel
                    } else if game.isAwaitingImpReplacementSelection {
                        impReplacementPanel
                    } else {
                        nightActionPanel
                    }

                    actionLogPanel
                }
                .animation(.easeInOut(duration: 0.24), value: expandedPlayerIDs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissActiveKeyboard()
                        }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                syncPassiveInfoSelection(from: nil, to: game.currentNightPassiveInfoSuggestedNote)
            }
            .onChange(of: game.currentNightStepIndex) { _, _ in
                manualNote = ""
                lastPassiveInfoSuggestedNote = nil
                syncPassiveInfoSelection(from: nil, to: game.currentNightPassiveInfoSuggestedNote)
            }
            .onChange(of: manualNote) { _, newValue in
                game.currentNightNote = newValue
            }
            .onChange(of: game.currentNightPassiveInfoSuggestedNote) { oldValue, newValue in
                syncPassiveInfoSelection(from: oldValue, to: newValue)
            }
        }
    }

    private var storytellerPanel: some View {
        GroupBox(game.ui("Players / Grimoire", "玩家信息 / 剧本书")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Review each player's role, status, and logs here.", "当前显示所有玩家的角色、状态和日志。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(game.players), id: \.id) { player in
                        PlayerRowView(
                            player: player,
                            role: player.roleId.flatMap { game.roleTemplate(for: $0) },
                            latestLog: player.roleLog.last(where: { !$0.hasPrefix("Assigned role:") && !$0.hasPrefix("分配角色：") }) ?? "",
                            isExpanded: expandedPlayerIDs.contains(player.id)
                        ) {
                            togglePlayerExpansion(player.id)
                        }
                    }
                }
            }
        }
    }

    private var dayVotingPanel: some View {
        GroupBox(game.ui("Nominations and Voting", "提名和投票")) {
            VStack(alignment: .leading, spacing: 10) {
                if game.alivePlayers.isEmpty {
                    Text(game.ui("No living players remain.", "尚无存活玩家。"))
                        .font(.caption)
                }

                dayThresholdSummary
                dayLockedResultsSection
                dayNominationSection
                dayStorytellerAbilities
                dayExecutionButtons
                slayerSection
            }
        }
    }

    private var dayThresholdSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.ui("Day \(game.currentDayNumber)", "第 \(game.currentDayNumber) 天"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if game.isRiotDay {
                Text(game.ui("Riot day: nominees die immediately. Keep nominating until all Riot are dead or only 2 players remain.", "暴乱日：被提名者会立即死亡。持续提名，直到所有暴乱死亡或只剩 2 人。"))
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if game.hasLeviathanInPlay {
                Text(game.ui("Leviathan: if more than 1 good player is executed, evil wins. If day 5 ends, evil wins.", "利维坦：若超过 1 名善良玩家被处决，邪恶获胜；若第 5 天结束，邪恶获胜。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(game.ui("Execution threshold: at least \(game.executionThreshold) votes based on current living players.", "执行门槛：至少 \(game.executionThreshold) 票（按当前活人数计算）"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dayLockedResultsSection: some View {
        if !game.nominationResults.isEmpty {
            Divider()
            Text(game.ui("Locked Results", "已锁定票数"))
                .font(.subheadline)

            ForEach(Array(game.votedCandidates), id: \.id) { candidate in
                dayLockedResultRow(candidate: candidate)
            }
        }
    }

    @ViewBuilder
    private var dayNominationSection: some View {
        if let nominee = game.currentNominee {
            dayCurrentNominationSection(nominee: nominee)
        } else if game.currentNominator != nil {
            dayNomineePickerSection
        } else {
            dayNominatorPickerSection
        }
    }

    private var dayExecutionButtons: some View {
        HStack {
            if !game.isRiotDay {
                Button(game.ui("Execute", "执行")) {
                    game.executeNomineeIfSet()
                }
                .disabled(game.nominationResults.isEmpty)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("day-execute")

                Button(game.ui("Skip", "跳过")) {
                    game.endDayWithoutExecution()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("day-skip")
            }
        }
    }

    @ViewBuilder
    private var dayStorytellerAbilities: some View {
        if game.canUseArtistToday() || game.canUseFishermanToday() || game.canUseAmnesiacToday() || game.canUseSavantToday() || game.canUseGossipToday() || game.canUseJugglerToday() || game.canUseAlsaahirToday() || game.canUseCultLeaderToday() || game.canUsePsychopathToday() || game.canUseWizardToday() || game.pendingMoonchild != nil {
            Divider()
        }

        if game.canUseArtistToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Artist", "艺术家"))
                    .font(.subheadline)
                TextField(game.ui("Record the private yes/no question and answer", "记录艺术家的私下是/否问题与回答"), text: $artistNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(game.ui("Execute", "执行")) {
                        game.recordArtistQuestion(artistNote)
                        artistNote = ""
                    }
                    .buttonStyle(.borderedProminent)

                    Button(game.ui("Cancel", "取消")) {
                        artistNote = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        if game.canUseFishermanToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Fisherman", "渔夫"))
                    .font(.subheadline)
                TextField(game.ui("Record the private advice", "记录渔夫得到的私下建议"), text: $fishermanNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(game.ui("Record Fisherman", "记录渔夫")) {
                    game.recordFishermanAdvice(fishermanNote)
                    fishermanNote = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(fishermanNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if game.canUseAmnesiacToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Amnesiac", "失忆者"))
                    .font(.subheadline)
                TextField(game.ui("Record the ruling, hint, or outcome", "记录失忆者能力裁定、提示或结果"), text: $amnesiacNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(game.ui("Record Amnesiac", "记录失忆者")) {
                    game.recordAmnesiacMoment(amnesiacNote)
                    amnesiacNote = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(amnesiacNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if game.canUseSavantToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Savant", "博学者"))
                    .font(.subheadline)
                TextField(game.ui("Record the two statements for today", "记录今天给博学者的两条陈述"), text: $savantNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(game.ui("Execute", "执行")) {
                        game.recordSavantInfo(savantNote)
                        savantNote = ""
                    }
                    .buttonStyle(.borderedProminent)

                    Button(game.ui("Cancel", "取消")) {
                        savantNote = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        if game.canUseGossipToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Gossip", "流言者"))
                    .font(.subheadline)
                TextField(game.ui("Record the public statement", "记录流言者的公开陈述"), text: $gossipNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(game.ui("False", "为假")) {
                        game.recordGossipStatement(gossipNote, isTrue: false)
                        gossipNote = ""
                    }
                    .buttonStyle(.bordered)

                    Button(game.ui("True", "为真")) {
                        game.recordGossipStatement(gossipNote, isTrue: true)
                        gossipNote = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .disabled(gossipNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if game.canUseJugglerToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Juggler", "杂耍演员"))
                    .font(.subheadline)
                TextField(game.ui("Record up to 5 public guesses", "记录最多 5 个公开角色猜测"), text: $jugglerNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(game.ui("Record Juggler", "记录杂耍演员")) {
                    game.recordJugglerGuesses(jugglerNote)
                    jugglerNote = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(jugglerNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if game.canUseAlsaahirToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Alsaahir", "阿尔萨希尔"))
                    .font(.subheadline)
                TextField(game.ui("Record the public evil-team guess", "记录公开宣称的整队邪恶猜测"), text: $alsaahirNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(game.ui("Resolve Alsaahir", "结算阿尔萨希尔")) {
                    game.resolveAlsaahirGuess(alsaahirNote)
                    alsaahirNote = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(alsaahirNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if game.canUseCultLeaderToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Cult Leader", "邪教领袖"))
                    .font(.subheadline)
                Text(game.ui("Run the cult vote. If every good player joins, the Cult Leader's team wins.", "进行邪教投票。若所有善良玩家都加入，邪教领袖阵营获胜。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(game.ui("Vote Failed", "投票失败")) {
                        game.resolveCultLeaderVote(allGoodJoined: false)
                    }
                    .buttonStyle(.bordered)

                    Button(game.ui("All Good Joined", "善良全员加入")) {
                        game.resolveCultLeaderVote(allGoodJoined: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

        if game.canUsePsychopathToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Psychopath", "精神病人"))
                    .font(.subheadline)
                Text(game.ui("Before nominations, publicly choose a player to die.", "在提名前，公开选择一名玩家死亡。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(game.psychopathTargetsToday()) { player in
                    let isSelected = selectedPsychopathTargetId == player.id
                    HStack {
                        Text(player.name)
                        Spacer()
                        if isSelected {
                            Button(game.ui("Selected", "已选")) {
                                selectedPsychopathTargetId = nil
                            }
                            .tint(.green)
                            .buttonStyle(.bordered)
                        } else {
                            Button(game.ui("Select", "选择")) {
                                selectedPsychopathTargetId = player.id
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
                Button(game.ui("Use Psychopath", "发动精神病人")) {
                    game.usePsychopathKill(targetId: selectedPsychopathTargetId)
                    selectedPsychopathTargetId = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPsychopathTargetId == nil)
            }
        }

        if game.canUseWizardToday() {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Wizard", "巫师"))
                    .font(.subheadline)
                TextField(game.ui("Record the wish and its cost", "记录愿望及其代价"), text: $wizardNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(game.ui("Record Wizard", "记录巫师")) {
                    game.recordWizardWish(wizardNote)
                    wizardNote = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(wizardNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if let moonchild = game.pendingMoonchild {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.ui("Moonchild", "月之子"))
                    .font(.subheadline)
                Text(game.ui("\(moonchild.name) must choose a player for the Moonchild ability.", "\(moonchild.name) 需要为月之子能力选择一名玩家。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(game.moonchildTargetCandidates) { player in
                    let isSelected = selectedMoonchildTargetId == player.id
                    HStack {
                        Text(player.name)
                        Spacer()
                        if isSelected {
                            Button(game.ui("Selected", "已选")) {
                                selectedMoonchildTargetId = nil
                            }
                            .tint(.green)
                            .buttonStyle(.bordered)
                        } else {
                            Button(game.ui("Select", "选择")) {
                                selectedMoonchildTargetId = player.id
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
                Button(game.ui("Confirm Moonchild", "确认月之子目标")) {
                    game.chooseMoonchildTarget(selectedMoonchildTargetId)
                    selectedMoonchildTargetId = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedMoonchildTargetId == nil)
            }
        }
    }

    @ViewBuilder
    private var slayerSection: some View {
        if game.canUseSlayerShot(), !game.isRiotDay {
            Divider()
            Text(game.ui("Slayer Action (once this day)", "猎手行动（本天仅可使用一次）"))
                .font(.subheadline)

            if game.isAwaitingSlayerRecluseChoice,
               let reclusePlayer = game.pendingSlayerReclusePlayer {
                slayerRecluseRegistrationSection(player: reclusePlayer)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(game.alivePlayers), id: \.id) { player in
                            slayerTargetButton(player: player)
                        }
                    }
                }
                HStack {
                    Button(game.ui("Execute", "执行")) {
                        game.useSlayerShot()
                    }
                    .disabled(game.slayerSelectedTarget == nil)
                    .buttonStyle(.borderedProminent)

                    Button(game.ui("Clear", "清空")) {
                        game.chooseSlayerTarget(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func slayerRecluseRegistrationSection(player: PlayerCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.ui(
                "\(player.name) is the Recluse. Does the Recluse register as the Demon for the Slayer?",
                "\(player.name) 是隐士。隐士在猎手技能判定中是否登记为恶魔？"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button(game.ui("Not Demon", "非恶魔")) {
                    game.resolveSlayerRecluseRegistration(registersAsDemon: false)
                }
                .buttonStyle(.bordered)

                Button(game.ui("Registers Demon", "登记为恶魔")) {
                    game.resolveSlayerRecluseRegistration(registersAsDemon: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func slayerTargetButton(player: PlayerCard) -> some View {
        let isSelected = game.slayerSelectedTarget == player.id

        return Group {
            if isSelected {
                Button(player.name) {
                    game.chooseSlayerTarget(nil)
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Button(player.name) {
                    game.chooseSlayerTarget(player.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func dayLockedResultRow(candidate: PlayerCard) -> some View {
        HStack {
            Text(candidate.name)
            Spacer()
            Text(game.ui("\(game.lockedVoteCount(for: candidate.id)) votes", "\(game.lockedVoteCount(for: candidate.id)) 票"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(game.leadingExecutionCandidate?.id == candidate.id ? .green : .secondary)
        }
    }

    private func dayCurrentNominationSection(nominee: PlayerCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let nominator = game.currentNominator {
                HStack(spacing: 12) {
                    Text("\(game.ui("Nominator", "提名者")): \(nominator.name)")
                    Text("\(game.ui("Nominee", "被提名者")): \(nominee.name)")
                }
                .font(.subheadline)
            } else {
                Text("\(game.ui("Nominee", "被提名者")): \(nominee.name)")
                    .font(.headline)
            }
            if !game.isRiotDay, game.canClaimGoblin(for: nominee.id) {
                HStack {
                    if game.goblinClaimedPlayerId == nominee.id {
                        Button(game.ui("Goblin Claimed", "已宣称地精")) {
                            game.setGoblinClaimed(false, for: nominee.id)
                        }
                        .tint(.green)
                        .buttonStyle(.bordered)
                    } else {
                        Button(game.ui("Claim Goblin", "宣称地精")) {
                            game.setGoblinClaimed(true, for: nominee.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            Text("\(game.ui("Current Votes", "本轮票数")): \(game.weightedVoteCount(for: nominee.id))")
                .font(.caption)

            if game.isAwaitingVirginRegistrationChoice,
               let registrationPlayer = game.pendingVirginRegistrationPlayer {
                virginRegistrationSection(player: registrationPlayer)
            } else {
                ForEach(Array(game.players), id: \.id) { voter in
                    dayVoteRow(voter: voter, nominee: nominee)
                }

                HStack {
                    Button(game.ui("Lock This Vote", "锁定本轮票数")) {
                        game.recordCurrentNomination()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("day-lockVote")

                    Button(game.ui("Cancel Nomination", "取消本轮提名")) {
                        game.clearCurrentNomination()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("day-cancelNomination")
                }
            }
        }
    }

    private func virginRegistrationSection(player: PlayerCard) -> some View {
        let roleName = game.localizedRoleName(game.roleTemplate(for: player.roleId ?? ""))
        return VStack(alignment: .leading, spacing: 8) {
            Text(game.ui(
                "Virgin: choose whether \(player.name) (\(roleName)) registers as Townsfolk.",
                "贞洁者：选择 \(player.name)（\(roleName)）是否登记为镇民。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button(game.ui("Not Townsfolk", "非镇民")) {
                    game.resolvePendingVirginRegistration(registersAsTownsfolk: false)
                }
                .buttonStyle(.bordered)

                Button(game.ui("Registers Townsfolk", "登记为镇民")) {
                    game.resolvePendingVirginRegistration(registersAsTownsfolk: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var dayNominatorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.ui("Choose a player to make the nomination.", "选择一名玩家作为提名者。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            ForEach(Array(game.availableNominatorsForDay), id: \.id) { player in
                Button {
                    game.setNominator(player.id)
                } label: {
                    HStack {
                        Text(player.name)
                        if !player.alive {
                            Text(game.ui("Banshee", "女妖"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("day-nominator-\(player.seatNumber)")
            }
        }
    }

    private var dayNomineePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.isRiotDay
                 ? game.ui("Choose a player to nominate. The nominee dies immediately.", "选择一名玩家提名。被提名者会立刻死亡。")
                 : game.ui("Choose the player to be nominated.", "选择被提名的玩家。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(game.ui("Cancel", "取消")) {
                game.setNominator(nil)
            }
            .buttonStyle(.bordered)
            Divider()
            ForEach(Array(game.availableNomineesForDay), id: \.id) { player in
                Button {
                    game.setNominee(player.id)
                } label: {
                    Text(player.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("day-nominee-\(player.seatNumber)")
            }
            if game.availableNomineesForDay.isEmpty {
                Text(game.ui("All living players have already been nominated this day.", "本日所有存活玩家都已完成提名计票。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dayVoteRow(voter: PlayerCard, nominee: PlayerCard) -> some View {
        let canParticipate = game.canParticipateInCurrentVote(voterId: voter.id)
        let canCastVoteNow = game.isVoteAllowed(voterId: voter.id, nominee: nominee.id)
        let hasVotedForNominee = game.votesByVoter[voter.id] == nominee.id
        let butlerReminder = game.butlerVoteReminder(voterId: voter.id, nominee: nominee.id)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(voter.name)
                if !voter.alive {
                    Text(game.playerVoteStatusText(for: voter))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let butlerReminder {
                    Text(butlerReminder)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canParticipate {
                if hasVotedForNominee {
                    Button(game.ui("Selected", "已投")) {
                        game.castVote(voter: voter.id, nominee: nil)
                    }
                    .tint(.green)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("day-vote-\(voter.seatNumber)")
                } else if canCastVoteNow {
                    Button(game.ui("Vote", "投票")) {
                        game.castVote(voter: voter.id, nominee: nominee.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("day-vote-\(voter.seatNumber)")
                } else {
                    Text(game.ui("Unavailable", "不可投"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(game.ui("Unavailable", "不可投"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var impReplacementPanel: some View {
        GroupBox(game.ui("Imp Replacement", "小恶魔替换")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    game.ui(
                        "The Imp died at night. Choose a living Minion to become the new Imp before the night continues.",
                        "小恶魔在夜里死亡。请选择一名存活爪牙成为新的小恶魔，然后继续本夜流程。"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(game.pendingImpReplacementCandidates) { candidate in
                    Button {
                        game.selectImpReplacement(candidate.id)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(game.teamColor(for: candidate))
                                .frame(width: 8, height: 8)
                            Text(candidate.name)
                                .foregroundStyle(.primary)
                            Text("(\(game.localizedRoleName(game.roleTemplate(for: candidate.roleId ?? ""))))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("night-impReplacement-\(candidate.seatNumber)")
                }
            }
        }
    }

    private var nightActionPanel: some View {
        GroupBox(game.ui("Wake order", "唤醒顺序")) {
            VStack(alignment: .leading, spacing: 10) {
                if game.isSelectingFortuneTellerRedHerring {
                    fortuneTellerRedHerringPanel
                } else {
                    if !game.currentNightSteps.isEmpty {
                        wakeProgressChart
                    }

                    if let step = game.currentNightStep,
                       let actor = game.currentNightActor,
                       let role = game.roleTemplate(for: step.roleId) {
                        VStack(alignment: .leading, spacing: 8) {
                            nightStepSection(step: step, actor: actor, role: role)
                            nightActionButtons
                        }
                    } else {
                        Text(game.ui("Night order is complete. Wait for dawn.", "夜间流程已结束，等待天亮。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var fortuneTellerRedHerringPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.ui("Select the Fortune Teller's red herring", "选择占卜师的\"恶魔标记\"玩家"))
                .font(.headline)
            Text(game.ui(
                "This good player will always register as a Demon to the Fortune Teller.",
                "该善良玩家将始终被占卜师视为恶魔。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(game.fortuneTellerRedHerringCandidates()) { candidate in
                Button {
                    game.selectFortuneTellerRedHerring(candidate.id)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(game.teamColor(for: candidate))
                            .frame(width: 8, height: 8)
                        Text("\(candidate.name) (\(game.localizedRoleName(game.roleTemplate(for: candidate.roleId ?? ""))))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("night-redherring-\(candidate.seatNumber)")
            }
        }
    }

    private func nightStepSection(step: NightStepTemplate, actor: PlayerCard, role: RoleTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(actor.name) (\(game.localizedRoleName(role)))")
                .font(.headline)
            Text(game.localizedRoleSummary(role))
                .font(.caption)

            nightTargetSection(for: step)
            pixieRoleChoiceSection(for: step)
            troubleBrewingRoleChoiceSection(for: step)
            nightAlignmentChoiceSection
            nightPassiveInfoSection
            nightNoteFieldSection(for: step)
        }
    }

    @ViewBuilder
    private func nightTargetSection(for step: NightStepTemplate) -> some View {
        if let infoText = game.nightInformationalText(for: step.roleId) {
            Text(infoText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if game.currentNightTargetLimit() > 0 && game.canUseNightTargetPicker(for: step.roleId) {
            Text("\(game.currentNightTargetPrompt()): \(game.currentNightTargets.count)/\(game.currentNightTargetLimit())")
                .font(.caption)
            ForEach(game.currentNightCandidates()) { candidate in
                nightTargetRow(candidate: candidate)
            }
        } else if game.currentNightTargetLimit() > 0 {
            Text(game.ui("Resolve this role manually and record the result below.", "该角色目前需要手动裁定，请在下方记录结果。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if step.roleId == "courtier" {
            Text(game.currentNightTargetPrompt())
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if game.nightInformationalText(for: step.roleId) != nil {
            EmptyView()
        } else {
            Text(game.ui("This role has no target this step. Record the result only.", "该角色本轮无目标，仅记录结果。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func nightTargetRow(candidate: PlayerCard) -> some View {
        let isSelected = game.currentNightTargets.contains(candidate.id)
        let isRedHerring = game.isFortuneTellerRedHerring(candidate.id)
            && game.currentNightStep?.roleId == "fortuneteller"

        return HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(game.teamColor(for: candidate))
                    .frame(width: 8, height: 8)
                Text(candidate.name)
                    .foregroundStyle(.primary)
                Text("(\(game.localizedRoleName(game.roleTemplate(for: candidate.roleId ?? ""))))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isRedHerring {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                }
            }
            Spacer()
            if isSelected {
                Button(game.ui("Selected", "已选")) {
                    game.toggleNightTarget(candidate.id)
                }
                .tint(.green)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .accessibilityIdentifier("night-target-\(candidate.seatNumber)")
            } else {
                Button(game.ui("Choose", "选择")) {
                    game.toggleNightTarget(candidate.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .accessibilityIdentifier("night-target-\(candidate.seatNumber)")
            }
        }
    }

    @ViewBuilder
    private func pixieRoleChoiceSection(for step: NightStepTemplate) -> some View {
        if step.roleId == "pixie" {
            Text(game.ui("Select a Townsfolk role:", "选择一个镇民角色："))
                .font(.caption.weight(.semibold))
            ForEach(game.pixieAvailableRoles()) { role in
                pixieRoleRow(role: role)
            }
        }
    }

    private func pixieRoleRow(role: RoleTemplate) -> some View {
        let isSelected = manualNote == role.id

        return HStack {
            Text(game.localizedRoleName(role))
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Button(game.ui("Selected", "已选")) {
                    manualNote = ""
                }
                .tint(.green)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                Button(game.ui("Choose", "选择")) {
                    manualNote = role.id
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func troubleBrewingRoleChoiceSection(for step: NightStepTemplate) -> some View {
        if game.hasNightRoleChoices(for: step.roleId) {
            let roleChoices = game.currentNightRoleChoices()

            Text(game.currentNightRoleChoicePrompt())
                .font(.caption.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(roleChoices) { option in
                        nightRoleChoiceRow(option: option)
                    }
                }
            }
        }
    }

    private func nightRoleChoiceRow(option: NightRoleChoiceOption) -> some View {
        let isSelected = manualNote == option.id

        return Group {
            if isSelected {
                Button {
                    updateNightRoleChoice(option: option, isSelected: true)
                } label: {
                    Text(game.localizedNightRoleChoiceLabel(option))
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Button {
                    updateNightRoleChoice(option: option, isSelected: false)
                } label: {
                    Text(game.localizedNightRoleChoiceLabel(option))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func updateNightRoleChoice(option: NightRoleChoiceOption, isSelected: Bool) {
        if isSelected {
            manualNote = ""
            game.currentNightNote = ""
            game.autoSelectPlayerForRoleChoice(nil)
            return
        }

        if option.roleId == nil {
            game.currentNightTargets.removeAll()
        }
        manualNote = option.id
        game.currentNightNote = option.id
        game.autoSelectPlayerForRoleChoice(option)
    }

    @ViewBuilder
    private var nightAlignmentChoiceSection: some View {
        let alignmentPlayers = game.currentNightAlignmentChoicePlayers()

        if !alignmentPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(alignmentPlayers, id: \.id) { player in
                    nightAlignmentChoiceRow(player: player)
                }
            }
        }
    }

    @ViewBuilder
    private var nightPassiveInfoSection: some View {
        if game.currentNightUsesPassiveInfoSelection {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.currentNightPassiveInfoSelectionPrompt())
                    .font(.caption.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(game.currentNightPassiveInfoSelectableNotes(), id: \.self) { note in
                            passiveInfoResultButton(note: note)
                        }
                    }
                }
            }
        }
    }

    private func passiveInfoResultButton(note: String) -> some View {
        let isSelected = manualNote == note

        return Group {
            if isSelected {
                Button(note) {
                    manualNote = note
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Button(note) {
                    manualNote = note
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func nightAlignmentChoiceRow(player: PlayerCard) -> some View {
        let selectedAlignment = game.currentNightAlignmentSelection(for: player.id)

        return VStack(alignment: .leading, spacing: 6) {
            Text(game.currentNightAlignmentPrompt(for: player))
                .font(.caption.weight(.semibold))

            HStack {
                alignmentChoiceButton(
                    title: game.ui("Good", "善良"),
                    isSelected: selectedAlignment == false,
                    tint: .green
                ) {
                    game.setCurrentNightAlignmentSelection(false, for: player.id)
                }

                alignmentChoiceButton(
                    title: game.ui("Evil", "邪恶"),
                    isSelected: selectedAlignment == true,
                    tint: .red
                ) {
                    game.setCurrentNightAlignmentSelection(true, for: player.id)
                }
            }
        }
    }

    private func alignmentChoiceButton(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Group {
            if isSelected {
                Button(title, action: action)
                    .tint(tint)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
            } else {
                Button(title, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func nightNoteFieldSection(for step: NightStepTemplate) -> some View {
        if game.shouldShowNightNoteField(for: step.roleId) {
            TextField(game.currentNightNotePrompt(), text: $manualNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var nightActionButtons: some View {
        HStack {
            Button(game.ui("Complete", "完成")) {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    game.completeCurrentNightAction()
                    manualNote = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("night-complete")

            Button(game.ui("Skip", "跳过")) {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    game.skipCurrentNightStep()
                    manualNote = ""
                }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("night-skip")
        }
        .id("nightActionButtons")
    }

    private var actionLogPanel: some View {
        GroupBox(game.ui("Event Log", "事件日志")) {
            ForEach(Array(game.gameLog), id: \.id) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.localizedGameEvent(event))
                        .font(.caption)
                        .foregroundStyle(game.color(for: event))
                    Text(event.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var wakeProgressChart: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(game.currentNightSteps.enumerated()), id: \.offset) { index, step in
                        wakeProgressChip(index: index, step: step)
                            .id(index)

                        if index < game.currentNightSteps.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary.opacity(0.55))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: game.currentNightStepIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(game.currentNightStepIndex, anchor: .center)
            }
        }
    }

    private func wakeProgressChip(index: Int, step: NightStepTemplate) -> some View {
        let isCurrent = index == game.currentNightStepIndex
        let isCompleted = index < game.currentNightStepIndex
        let isSkipped = game.skippedNightStepIndices.contains(index)
        let role = game.roleTemplate(for: step.roleId)
        let playerName = game.wakeProgressPlayer(for: step)?.name ?? game.ui("Out", "未上场")
        let currentAccent: Color = switch game.currentNightReminderHighlightStyle {
        case .poison:
            Color(uiColor: .systemPurple)
        case .drunk:
            Color(uiColor: .systemOrange)
        case nil:
            .blue
        }
        let pendingFill = Color(uiColor: .secondarySystemBackground)
        let pendingStroke = Color(uiColor: .separator).opacity(0.55)
        let fill: Color = isCurrent
            ? currentAccent.opacity(0.2)
            : (isSkipped ? .gray.opacity(0.12) : (isCompleted ? .green.opacity(0.16) : pendingFill))
        let stroke: Color = isCurrent
            ? currentAccent.opacity(0.72)
            : (isSkipped ? .gray.opacity(0.35) : (isCompleted ? .green.opacity(0.45) : pendingStroke))
        let indexColor: Color = isCurrent ? currentAccent.opacity(0.95) : .secondary

        return VStack(alignment: .leading, spacing: 4) {
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(indexColor)
            Text(playerName)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text(game.localizedRoleName(role))
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 72, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private func togglePlayerExpansion(_ playerID: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPlayerIDs.contains(playerID) {
                expandedPlayerIDs.remove(playerID)
            } else {
                expandedPlayerIDs.insert(playerID)
            }
        }
    }

    private func syncPassiveInfoSelection(from oldValue: String?, to newValue: String?) {
        defer {
            lastPassiveInfoSuggestedNote = newValue
        }

        guard game.currentNightUsesPassiveInfoSelection,
              let newValue else {
            return
        }

        let shouldFollowSuggestedValue = manualNote.isEmpty || manualNote == oldValue || manualNote == lastPassiveInfoSuggestedNote
        if shouldFollowSuggestedValue {
            manualNote = newValue
        }
    }
}

#if DEBUG
struct GameFlowView_Previews: PreviewProvider {
    static var previews: some View {
        GameFlowView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif
