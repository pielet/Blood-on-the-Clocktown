import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                phaseHeader

                Group {
                    switch game.phase {
                    case .templateSelection:
                        TemplateSelectionView()
                    case .playerSetup:
                        PlayerSetupView()
                    case .assignment:
                        AssignmentView()
                    case .impBluffs:
                        ImpBluffSetupView()
                    case .impBluffsReveal:
                        ImpBluffRevealView()
                    case .firstNight, .night, .day:
                        GameFlowView()
                    case .finished:
                        GameOverView()
                    }
                }
            }
            .padding()
            .navigationTitle(game.appDisplayName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(game.restartButtonTitle, role: .destructive) {
                        game.resetGame()
                    }
                    .accessibilityIdentifier("content-restart")
                }
            }
        }
            .onAppear {
                if game.players.isEmpty {
                    game.startTemplateSelection()
                }
        }
    }

    private var phaseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.ui("Current Phase", "当前阶段"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(game.gamePhaseTitle())
                    .font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Picker("Language", selection: $game.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.shortLabel).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 112)

                if game.phase == .day {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(game.ui("Timer", "计时器"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerText)
                            .font(.title3.monospacedDigit())
                        HStack(spacing: 6) {
                            Button(game.timerRunning ? game.ui("Pause", "暂停") : game.ui("Start", "开始")) {
                                game.toggleTimer()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                            timerAddButton(60)
                            timerAddButton(120)
                            timerAddButton(300)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private func timerAddButton(_ seconds: Int) -> some View {
        Button(timerAddLabel(for: seconds)) {
            game.addDayTime(seconds: seconds)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func timerAddLabel(for seconds: Int) -> String {
        let minutes = seconds / 60
        return game.ui("+\(minutes) min", "+\(minutes)分钟")
    }

    private var timerText: String {
        let minutes = game.phaseSecondsLeft / 60
        let seconds = game.phaseSecondsLeft % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif
