import SwiftUI

struct TemplateSelectionView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(game.ui("Choose an Edition", "选择剧本"))
                .font(.headline)

            ForEach(game.templates) { template in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.localizedTemplateName(template))
                            .font(.title3.bold())
                        Text("\(game.ui("Recommended", "推荐配置")): \(game.templateSummary(for: template))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle(
                        isOn: Binding(
                            get: { game.isExperimentalEnabled(for: template.id) },
                            set: { game.setExperimentalEnabled($0, for: template.id) }
                        )
                    ) {
                        Text(game.ui("Include Experimental Roles", "加入实验角色"))
                            .font(.caption.weight(.semibold))
                    }
                    .toggleStyle(.switch)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                .contentShape(Rectangle())
                .onTapGesture {
                    game.selectTemplate(template.id)
                }
                .accessibilityIdentifier("template-\(template.id)")
            }
        }
    }
}
