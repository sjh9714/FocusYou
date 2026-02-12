import Foundation

extension String {
    /// URL 문자열을 정규화된 도메인으로 변환
    /// "https://www.Facebook.com/path?q=1" → "facebook.com"
    var normalizedDomain: String {
        var domain = self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 프로토콜 제거
        if let range = domain.range(of: "://") {
            domain = String(domain[range.upperBound...])
        }

        // www. 접두사 제거
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }

        // 경로, 쿼리, 프래그먼트 제거
        if let slashIndex = domain.firstIndex(of: "/") {
            domain = String(domain[..<slashIndex])
        }

        // 포트 번호 제거
        if let colonIndex = domain.firstIndex(of: ":") {
            domain = String(domain[..<colonIndex])
        }

        // 빈 문자열 또는 유효하지 않은 도메인 체크
        guard !domain.isEmpty, domain.contains(".") else {
            return ""
        }

        return domain
    }

    /// 유효한 도메인인지 확인
    var isValidDomain: Bool {
        !normalizedDomain.isEmpty
    }
}
