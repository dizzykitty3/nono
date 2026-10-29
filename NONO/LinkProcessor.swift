import Foundation

enum LinkProcessor {
    nonisolated private static let trackingKeys: Set<String> = [
        "s", "fbclid", "gclid", "dclid", "igshid", "mc_cid", "mc_eid"
    ]

    nonisolated static func organize(_ input: String) -> String {
        let cleaned = extractLinks(from: input).compactMap(clean)
        let unique = Dictionary(grouping: cleaned, by: \.url)
            .compactMap { $0.value.first }

        let organizedLinks = unique
            .sorted { lhs, rhs in
                lhs.sortKey.localizedCaseInsensitiveCompare(rhs.sortKey) == .orderedAscending
            }
        let sections = Dictionary(grouping: organizedLinks, by: \.sectionTitle)
        let groupedLinks = sections
            .keys
            .sorted { lhs, rhs in
                if lhs == "#" { return false }
                if rhs == "#" { return true }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            .flatMap { sectionTitle in
                [sectionTitle] + (sections[sectionTitle] ?? []).map(\.url)
            }

        let title = notesTitle(in: input)
        let output = (title.map { [$0] } ?? []) + groupedLinks
        return output.joined(separator: "\n")
    }

    nonisolated static func linkCount(in input: String) -> Int {
        let cleaned = extractLinks(from: input).compactMap(clean)
        return Set(cleaned.map(\.url)).count
    }

    nonisolated private static func extractLinks(from input: String) -> [String] {
        // This also picks up URLs inside Notes-style Markdown links.
        let pattern = #"(?i)https?://[^\s<>\]\)]+|(?<![\w/@.:-])(?:www\.)?iwara\.tv/profile/[^\s<>\]\)]+"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(input.startIndex..., in: input)
        return expression.matches(in: input, range: range).compactMap {
            Range($0.range, in: input).map { String(input[$0]) }
        }
    }

    nonisolated private static func notesTitle(in input: String) -> String? {
        guard let firstLine = input.split(separator: "\n", omittingEmptySubsequences: false).first else {
            return nil
        }
        let title = String(firstLine)
        return extractLinks(from: title).isEmpty && !title.isEmpty ? title : nil
    }

    nonisolated private static func clean(_ rawURL: String) -> Link? {
        let rawURL = rawURL.contains("://") ? rawURL : "https://" + rawURL
        // Encode Unicode before parsing so existing percent escapes are not encoded twice.
        let asciiURLCharacters = CharacterSet(charactersIn: "\u{21}"..."\u{7E}")
        guard let encodedURL = rawURL.addingPercentEncoding(withAllowedCharacters: asciiURLCharacters),
              var components = URLComponents(string: encodedURL),
              let host = components.host else { return nil }

        components.fragment = nil
        components.queryItems = components.queryItems?.filter { item in
            let key = item.name.lowercased()
            return !trackingKeys.contains(key) && !key.hasPrefix("utm_")
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }

        guard let cleanedURL = components.url?.absoluteString else { return nil }
        let identifier = queryIdentifier(host: host, path: components.path, items: components.queryItems ?? [])
            ?? profileIdentifier(host: host, path: components.path)
            ?? host.lowercased()
        let sortKey = normalizedSortKey(for: identifier)
        return Link(url: readableURL(cleanedURL), sortKey: sortKey, sectionTitle: sectionTitle(for: sortKey))
    }

    nonisolated private static func readableURL(_ url: String) -> String {
        // Decode only UTF-8 non-ASCII bytes; escaped URL delimiters must stay escaped.
        guard let expression = try? NSRegularExpression(pattern: #"(?i)(?:%[CD][0-9A-F]%[89AB][0-9A-F]|%E[0-9A-F](?:%[89AB][0-9A-F]){2}|%F[0-4](?:%[89AB][0-9A-F]){3})"#) else {
            return url
        }
        var result = url
        let matches = expression.matches(in: url, range: NSRange(url.startIndex..., in: url))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let decoded = String(result[range]).removingPercentEncoding,
                  decoded.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else {
                continue
            }
            result.replaceSubrange(range, with: decoded)
        }
        return result
    }

    nonisolated private static func normalizedSortKey(for identifier: String) -> String {
        let withoutUnderscores = identifier.replacingOccurrences(of: "_", with: "")
        let key = withoutUnderscores.isEmpty ? identifier : withoutUnderscores
        return key.applyingTransform(.toLatin, reverse: false) ?? key
    }

    nonisolated private static func queryIdentifier(host: String, path: String, items: [URLQueryItem]) -> String? {
        // URLComponents handles separators and percent decoding without splitting encoded values.
        let candidates = items.compactMap { item -> (key: String, value: String)? in
            guard let value = item.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return (item.name.lowercased(), value)
        }
        let normalizedHost = host.lowercased().hasPrefix("www.")
            ? String(host.lowercased().dropFirst(4)) : host.lowercased()
        if normalizedHost == "18comic.vip", path == "/search/photos" || path == "/search/photos/",
           let value = candidates.first(where: { $0.key == "search_query" })?.value {
            return value
        }
        if normalizedHost == "hanime1.me", path == "/search" || path == "/search/",
           let value = candidates.first(where: { $0.key == "query" })?.value {
            return value
        }

        for key in ["user_id", "userid", "uid", "username", "user", "member_id", "memberid", "profile_id", "profileid", "account", "id"] {
            if let value = candidates.first(where: { $0.key == key })?.value { return value }
        }

        // Keep existing profile paths authoritative when only incidental parameters remain.
        let segments = path.split(separator: "/")
        let genericPaths: Set<String> = ["search", "user", "users", "profile", "member", "account", "index", "index.php", "user.php", "profile.php", "member.php", "search.php"]
        guard segments.isEmpty || (segments.count == 1 && genericPaths.contains(String(segments[0]).lowercased())) else {
            return nil
        }
        for key in ["query", "q", "keyword", "keywords", "search"] {
            if let value = candidates.first(where: { $0.key == key })?.value { return value }
        }
        let incidentalKeys: Set<String> = ["page", "p", "limit", "offset", "sort", "order", "lang", "locale", "ref", "source", "redirect", "redirect_uri", "return", "return_to", "token", "access_token", "session"]
        let remaining = candidates.filter { !incidentalKeys.contains($0.key) }
        return remaining.count == 1 ? remaining[0].value : nil
    }

    nonisolated private static func sectionTitle(for sortKey: String) -> String {
        guard let first = sortKey.first else { return "#" }
        if first.isNumber { return "#" }
        guard let firstLetter = sortKey.first(where: \.isLetter) else { return "#" }
        return String(firstLetter).uppercased()
    }

    nonisolated private static func profileIdentifier(host: String, path: String) -> String? {
        let normalizedHost = host.lowercased().hasPrefix("www.")
            ? String(host.lowercased().dropFirst(4))
            : host.lowercased()
        let segments = path.split(separator: "/").map(String.init)
        guard let first = segments.first else { return nil }

        let identifier: String?
        switch normalizedHost {
        case "iwara.tv":
            identifier = first == "profile" ? segments.dropFirst().first : first
        case "my.erohere.eu":
            identifier = first == "search" ? segments.dropFirst().first ?? first : first
        case "nhentai.net":
            identifier = first == "artist" ? segments.dropFirst().first : first
        case "pixiv.net":
            if first == "users" {
                identifier = segments.dropFirst().first
            } else if segments.count >= 3, segments[1] == "users" {
                // Pixiv profile links can include a language prefix, such as /en/users/123.
                identifier = segments[2]
            } else {
                identifier = first
            }
        case "weibo.com":
            identifier = (first == "n" || first == "u") ? segments.dropFirst().first : first
        default:
            identifier = first
        }

        guard let identifier, !identifier.isEmpty else { return nil }
        return identifier.removingPercentEncoding ?? identifier
    }

    private struct Link {
        let url: String
        let sortKey: String
        let sectionTitle: String
    }
}
