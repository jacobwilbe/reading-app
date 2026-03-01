import SwiftUI

struct RecommendationResultCardView: View {
    let candidate: ArticleCandidate
    let estimatedMinutes: Int?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(candidate.source.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let estimatedMinutes {
                        Label("\(estimatedMinutes) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(candidate.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if !candidate.snippet.isEmpty {
                    Text(candidate.snippet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text(candidate.licenseType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Read")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
