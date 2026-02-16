import SwiftUI

// MARK: - 명언 뷰 (v1.5)

struct QuoteView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var currentQuote: QuoteEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(themeManager.accent.opacity(0.6))
                Spacer()
            }

            if let quote = currentQuote {
                Text(quote.text)
                    .font(.callout.italic())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frostedCard()
        .onAppear {
            currentQuote = QuoteService.randomQuote()
        }
        .onTapGesture {
            withAnimation(.quickEase) {
                currentQuote = QuoteService.randomQuote()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentQuote.map { "\($0.text) — \($0.author)" } ?? "명언")
        .accessibilityHint("탭하여 다른 명언 보기")
    }
}

// MARK: - 명언 데이터

struct QuoteEntry: Codable, Identifiable {
    var id: String { text }
    let text: String
    let author: String
    let locale: String
}

enum QuoteService {
    private static let quotes: [QuoteEntry] = {
        guard let url = Bundle.main.url(forResource: "Quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([QuoteEntry].self, from: data) else {
            return []
        }
        return entries
    }()

    /// 현재 로케일에 맞는 명언 랜덤 반환
    static func randomQuote() -> QuoteEntry? {
        let localePrefix = Locale.current.language.languageCode?.identifier ?? "en"
        let filtered = quotes.filter { $0.locale == localePrefix }
        return (filtered.isEmpty ? quotes : filtered).randomElement()
    }

    /// 알림용 짧은 텍스트 ("명언 — 저자")
    static func randomQuoteText() -> String? {
        guard let quote = randomQuote() else { return nil }
        return "\(quote.text) — \(quote.author)"
    }
}

#Preview {
    QuoteView()
        .environment(ThemeManager.shared)
        .frame(width: 350)
        .padding()
}
