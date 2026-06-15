import Foundation

struct AssetRewriteResult {
    let text: String
    let assetDirectory: URL?
}

struct HTMLAssetBundler {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func rewriteHTMLWithBundledAssets(
        _ html: String,
        inputURL: URL,
        outputURL: URL
    ) throws -> AssetRewriteResult {
        let mapping = try copyReferencedAssets(from: html, inputURL: inputURL, outputURL: outputURL)
        return AssetRewriteResult(
            text: rewriteReferences(in: html, using: mapping.references),
            assetDirectory: mapping.assetDirectory
        )
    }

    func rewriteMarkdownWithBundledAssets(
        _ markdown: String,
        sourceHTML: String,
        inputURL: URL,
        outputURL: URL
    ) throws -> AssetRewriteResult {
        let mapping = try copyReferencedAssets(from: sourceHTML, inputURL: inputURL, outputURL: outputURL)
        return AssetRewriteResult(
            text: rewriteReferences(in: markdown, using: mapping.references),
            assetDirectory: mapping.assetDirectory
        )
    }

    private func copyReferencedAssets(
        from html: String,
        inputURL: URL,
        outputURL: URL
    ) throws -> (references: [String: String], assetDirectory: URL?) {
        let baseDirectory = inputURL.deletingLastPathComponent().standardizedFileURL
        let assetDirectory = outputURL
            .deletingPathExtension()
            .deletingLastPathComponent()
            .appendingPathComponent("\(outputURL.deletingPathExtension().lastPathComponent)_assets", isDirectory: true)

        var rewrites: [String: String] = [:]
        var copiedDestinations = Set<String>()

        for reference in extractReferences(from: html) {
            guard rewrites[reference] == nil,
                  let localReference = LocalAssetReference(reference),
                  let sourceURL = sourceURL(for: localReference.path, baseDirectory: baseDirectory),
                  isRegularFile(sourceURL) else {
                continue
            }

            let encodedRelativePath = encodeRelativePath(localReference.decodedPath)
            let destinationURL = assetDirectory.appendingPathComponent(localReference.decodedPath)
            let destinationDirectory = destinationURL.deletingLastPathComponent()

            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            if !copiedDestinations.contains(destinationURL.path) {
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
                copiedDestinations.insert(destinationURL.path)
            }

            rewrites[reference] = "\(assetDirectory.lastPathComponent)/\(encodedRelativePath)\(localReference.suffix)"
        }

        return (rewrites, rewrites.isEmpty ? nil : assetDirectory)
    }

    private func sourceURL(for relativePath: String, baseDirectory: URL) -> URL? {
        let decodedPath = relativePath.removingPercentEncoding ?? relativePath
        let sourceURL = baseDirectory.appendingPathComponent(decodedPath).standardizedFileURL
        let basePath = baseDirectory.path.hasSuffix("/") ? baseDirectory.path : "\(baseDirectory.path)/"

        guard sourceURL.path.hasPrefix(basePath) else {
            return nil
        }

        return sourceURL
    }

    private func isRegularFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        return !isDirectory.boolValue
    }

    private func extractReferences(from html: String) -> [String] {
        var references = Set<String>()

        let attributePattern = #"(?i)\b(?:src|href|poster|srcset)\s*=\s*["']([^"']+)["']"#
        for value in matches(pattern: attributePattern, in: html) {
            if value.contains(",") {
                for srcsetReference in parseSrcset(value) {
                    references.insert(srcsetReference)
                }
            } else {
                references.insert(value)
            }
        }

        let cssURLPattern = #"(?i)url\(\s*['"]?([^'")]+)['"]?\s*\)"#
        for value in matches(pattern: cssURLPattern, in: html) {
            references.insert(value)
        }

        return Array(references)
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return String(text[valueRange])
        }
    }

    private func parseSrcset(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .compactMap { candidate in
                candidate
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(whereSeparator: { $0 == " " || $0 == "\t" })
                    .first
                    .map(String.init)
            }
    }

    private func rewriteReferences(in text: String, using rewrites: [String: String]) -> String {
        rewrites
            .sorted { $0.key.count > $1.key.count }
            .reduce(text) { partial, rewrite in
                partial.replacingOccurrences(of: rewrite.key, with: rewrite.value)
            }
    }

    private func encodeRelativePath(_ path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            .joined(separator: "/")
    }
}

private struct LocalAssetReference {
    let path: String
    let decodedPath: String
    let suffix: String

    init?(_ rawReference: String) {
        let trimmed = rawReference.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("#"),
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("//"),
              !trimmed.lowercased().hasPrefix("http://"),
              !trimmed.lowercased().hasPrefix("https://"),
              !trimmed.lowercased().hasPrefix("data:"),
              !trimmed.lowercased().hasPrefix("mailto:"),
              !trimmed.lowercased().hasPrefix("tel:"),
              !trimmed.lowercased().hasPrefix("javascript:") else {
            return nil
        }

        let split = Self.splitPathAndSuffix(trimmed)
        let decoded = split.path.removingPercentEncoding ?? split.path

        guard !decoded.isEmpty,
              !decoded.contains("://") else {
            return nil
        }

        path = split.path
        decodedPath = decoded
        suffix = split.suffix
    }

    private static func splitPathAndSuffix(_ reference: String) -> (path: String, suffix: String) {
        let queryIndex = reference.firstIndex(of: "?")
        let fragmentIndex = reference.firstIndex(of: "#")
        let firstSuffixIndex: String.Index?

        switch (queryIndex, fragmentIndex) {
        case let (.some(query), .some(fragment)):
            firstSuffixIndex = query < fragment ? query : fragment
        case let (.some(query), .none):
            firstSuffixIndex = query
        case let (.none, .some(fragment)):
            firstSuffixIndex = fragment
        case (.none, .none):
            firstSuffixIndex = nil
        }

        guard let firstSuffixIndex else {
            return (reference, "")
        }

        return (
            String(reference[..<firstSuffixIndex]),
            String(reference[firstSuffixIndex...])
        )
    }
}
