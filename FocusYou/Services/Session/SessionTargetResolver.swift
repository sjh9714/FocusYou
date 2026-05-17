import Foundation

struct SessionBlockingTargets: Equatable {
    let domains: [String]
    let appBundleIds: [String]
    let blocklistMode: String

    var hasBlockingTargets: Bool {
        PersistedBlocklistMode(storedValue: blocklistMode).hasBlockingTargets(
            domains: domains,
            appBundleIds: appBundleIds
        )
    }
}

struct SessionTargetResolver {
    func resolve(
        sites: [BlockedSite],
        apps: [BlockedApp],
        blocklistMode: String
    ) -> SessionBlockingTargets {
        let enabledDomains = sites.filter(\.isEnabled).flatMap { site -> [String] in
            if site.isKeywordPattern ?? false {
                return HostsFileManager.shared.expandKeywordPattern(site.domain)
            }
            return [site.domain]
        }

        let effectiveBundleIds = apps
            .filter(\.isEnabled)
            .map(\.bundleId)

        return SessionBlockingTargets(
            domains: enabledDomains,
            appBundleIds: effectiveBundleIds,
            blocklistMode: PersistedBlocklistMode(storedValue: blocklistMode).rawValue
        )
    }
}
