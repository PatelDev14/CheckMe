import SwiftUI

// Small horizontal strip shown in scan result views when the user has a profile.
// Communicates which profile attributes influenced the current analysis,
// so users understand the result is personalised to them.

struct ProfileAttributionBanner: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))

                    Text("Personalised using:")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize()

                    ForEach(tags.prefix(6), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.80))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
