import Foundation

public enum HTMLConversionError: LocalizedError, Equatable, Sendable {
    case missingInput
    case missingFile(URL)
    case unsupportedInput(URL)
    case outputDirectoryUnavailable(URL)
    case renderingFailed(String)
    case markdownExtractionFailed
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .missingInput:
            "변환할 HTML 파일을 선택해 주세요."
        case let .missingFile(url):
            "파일을 찾을 수 없습니다: \(url.path)"
        case let .unsupportedInput(url):
            "HTML 또는 HTM 파일만 변환할 수 있습니다: \(url.lastPathComponent)"
        case let .outputDirectoryUnavailable(url):
            "저장 폴더를 사용할 수 없습니다: \(url.path)"
        case let .renderingFailed(message):
            "HTML 렌더링에 실패했습니다: \(message)"
        case .markdownExtractionFailed:
            "Markdown 추출 결과를 읽을 수 없습니다."
        case .pngEncodingFailed:
            "PNG 이미지 데이터를 만들 수 없습니다."
        }
    }
}

@MainActor
public final class HTMLConversionService {
    private let fileManager: FileManager
    private let assetBundler: HTMLAssetBundler

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        assetBundler = HTMLAssetBundler(fileManager: fileManager)
    }

    public func convert(
        inputURL: URL,
        format: OutputFormat,
        destinationDirectory: URL
    ) async throws -> URL {
        try validateInput(inputURL)
        try validateOutputDirectory(destinationDirectory)

        let outputURL = try uniqueOutputURL(
            for: inputURL,
            format: format,
            destinationDirectory: destinationDirectory
        )

        switch format {
        case .jsp:
            let html = try readHTMLText(from: inputURL)
            let result = try assetBundler.rewriteHTMLWithBundledAssets(
                html,
                inputURL: inputURL,
                outputURL: outputURL
            )
            try result.text.write(to: outputURL, atomically: true, encoding: .utf8)
        case .markdown:
            let renderer = HTMLRenderer()
            try await renderer.load(fileURL: inputURL)
            let html = try readHTMLText(from: inputURL)
            let markdown = try await renderer.makeMarkdown()
            let result = try assetBundler.rewriteMarkdownWithBundledAssets(
                markdown,
                sourceHTML: html,
                inputURL: inputURL,
                outputURL: outputURL
            )
            try result.text.write(to: outputURL, atomically: true, encoding: .utf8)
        case .pdf:
            let renderer = HTMLRenderer()
            try await renderer.load(fileURL: inputURL)
            let pdfData = try await renderer.makePDFData()
            try pdfData.write(to: outputURL, options: .atomic)
        case .png:
            let renderer = HTMLRenderer()
            try await renderer.load(fileURL: inputURL)
            let pngData = try await renderer.makePNGData()
            try pngData.write(to: outputURL, options: .atomic)
        }

        return outputURL
    }

    private func readHTMLText(from inputURL: URL) throws -> String {
        let data = try Data(contentsOf: inputURL)

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func validateInput(_ inputURL: URL) throws {
        guard inputURL.isFileURL else {
            throw HTMLConversionError.unsupportedInput(inputURL)
        }

        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw HTMLConversionError.missingFile(inputURL)
        }

        let fileExtension = inputURL.pathExtension.lowercased()
        guard ["html", "htm"].contains(fileExtension) else {
            throw HTMLConversionError.unsupportedInput(inputURL)
        }
    }

    private func validateOutputDirectory(_ destinationDirectory: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw HTMLConversionError.outputDirectoryUnavailable(destinationDirectory)
        }
    }

    private func uniqueOutputURL(
        for inputURL: URL,
        format: OutputFormat,
        destinationDirectory: URL
    ) throws -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        var candidate = destinationDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension(format.fileExtension)

        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = destinationDirectory
                .appendingPathComponent("\(baseName)-\(index)")
                .appendingPathExtension(format.fileExtension)
            index += 1
        }

        return candidate
    }
}
