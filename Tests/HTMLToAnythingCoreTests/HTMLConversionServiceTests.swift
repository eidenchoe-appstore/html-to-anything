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
        try """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Sample</title>
          <style>body { font-family: -apple-system; padding: 32px; }</style>
        </head>
        <body>
          <h1>Quarterly Brief</h1>
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

        let jspURL = directory.appendingPathComponent("sample.jsp")
        let jsp = try String(contentsOf: jspURL, encoding: .utf8)
        XCTAssertTrue(jsp.contains("<h1>Quarterly Brief</h1>"))
    }
}
