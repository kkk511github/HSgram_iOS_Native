import Foundation

extension HSSupergroupMember {
    func matchesMemberSearch(_ query: String) -> Bool {
        let normalizedQuery = query.memberSearchNormalized
        guard !normalizedQuery.isEmpty else {
            return true
        }
        return displayName.memberSearchNormalized.contains(normalizedQuery)
            || (username?.memberSearchNormalized.hasPrefix(normalizedQuery) ?? false)
            || role.memberSearchNormalized.contains(normalizedQuery)
            || (rank?.memberSearchNormalized.contains(normalizedQuery) ?? false)
    }
}

private extension String {
    var memberSearchNormalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
