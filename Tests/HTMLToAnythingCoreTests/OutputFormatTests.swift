import XCTest
@testable import HTMLToAnythingCore

final class OutputFormatTests: XCTestCase {
    func testFormatsHaveUniqueFileExtensions() {
        let extensions = OutputFormat.allCases.map(\.fileExtension)
        XCTAssertEqual(Set(extensions).count, extensions.count)
    }

    func testAllFormatsHaveUserVisibleMetadata() {
        for format in OutputFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty)
            XCTAssertFalse(format.systemImage.isEmpty)
            XCTAssertFalse(format.summary.isEmpty)
        }
    }
}
