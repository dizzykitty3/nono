//
//  LinkProcessor.swift
//  NONO
//

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
            .map(\.url)

        let title = notesTitle(in: input)
        let output = (title.map { [$0] } ?? []) + organizedLinks
        return output.joined(separator: "\n")
    }

    nonisolated static func linkCount(in input: String) -> Int {
        let cleaned = extractLinks(from: input).compactMap(clean)
        return Set(cleaned.map(\.url)).count
    }

    nonisolated private static func extractLinks(from input: String) -> [String] {
        // This also picks up URLs inside Notes-style Markdown links.
        let pattern = #"https?://[^\s<>\]\)]+"#
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
        guard var components = URLComponents(string: rawURL),
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
        let sortKey = profileIdentifier(host: host, path: components.path) ?? host.lowercased()
        return Link(url: cleanedURL, sortKey: sortKey)
    }

    nonisolated private static func profileIdentifier(host: String, path: String) -> String? {
        let normalizedHost = host.lowercased().hasPrefix("www.")
            ? String(host.lowercased().dropFirst(4))
            : host.lowercased()
        let segments = path.split(separator: "/").map(String.init)
        guard let first = segments.first else { return nil }

        let identifier: String?
        switch normalizedHost {
        case "nhentai.net":
            identifier = first == "artist" ? segments.dropFirst().first : first
        case "pixiv.net":
            identifier = first == "users" ? segments.dropFirst().first : first
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
    }
}
