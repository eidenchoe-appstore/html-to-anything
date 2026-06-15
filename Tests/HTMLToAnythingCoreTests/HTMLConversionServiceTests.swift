import XCTest
@testable import HTMLToAnythingCore

final class HTMLConversionServiceTests: XCTestCase {
    func testConvertsSimpleHTMLToAllFormats() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("HTMLToAnythingTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.html")
        let assetDirectory = directory.appendingPathComponent("assets", isDirectory: true)
        try fileManager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        try """
        body { color: #223344; }
        .hero { border: 1px solid #ccd6e0; }
        """.write(to: assetDirectory.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)
        try """
        <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">
          <rect width="80" height="80" rx="12" fill="#0a84ff"/>
          <text x="40" y="48" font-size="24" fill="white" text-anchor="middle">H</text>
        </svg>
        """.write(to: assetDirectory.appendingPathComponent("logo.svg"), atomically: true, encoding: .utf8)

        try """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Sample</title>
          <link rel="stylesheet" href="assets/style.css">
          <style>body { font-family: -apple-system; padding: 32px; }</style>
        </head>
        <body>
          <h1>Quarterly Brief</h1>
          <img class="hero" src="assets/logo.svg" alt="HTML logo">
          <p>Revenue increased <strong>12%</strong> this quarter.</p>
          <ul>
            <li>PDF export</li>
            <li>PNG export</li>
          </ul>
        </body>
        </html>
        """.write(to: inputURL, atomically: true, encoding: .utf8)

        let service = await MainActor.run {
            HTMLConversionService()
        }

        for format in OutputFormat.allCases {
            let outputURL = try await service.convert(
                inputURL: inputURL,
                format: format,
                destinationDirectory: directory
            )

            XCTAssertTrue(fileManager.fileExists(atPath: outputURL.path))
            XCTAssertEqual(outputURL.pathExtension, format.fileExtension)

            let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
            let size = try XCTUnwrap(attributes[.size] as? NSNumber)
            XCTAssertGreaterThan(size.intValue, 0)
        }

        let markdownURL = directory.appendingPathComponent("sample.md")
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(markdown.contains("# Quarterly Brief"))
        XCTAssertTrue(markdown.contains("**12%**"))
        XCTAssertTrue(markdown.contains("sample_assets/assets/logo.svg"))

        let jspURL = directory.appendingPathComponent("sample.jsp")
        let jsp = try String(contentsOf: jspURL, encoding: .utf8)
        XCTAssertTrue(jsp.contains("<h1>Quarterly Brief</h1>"))
        XCTAssertTrue(jsp.contains("sample_assets/assets/style.css"))
        XCTAssertTrue(jsp.contains("sample_assets/assets/logo.svg"))

        XCTAssertTrue(fileManager.fileExists(atPath: directory.appendingPathComponent("sample_assets/assets/style.css").path))
        XCTAssertTrue(fileManager.fileExists(atPath: directory.appendingPathComponent("sample_assets/assets/logo.svg").path))
    }
}
