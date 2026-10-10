import XCTest
@testable import Coastline

final class AssumptionInfoTests: XCTestCase {
    func testEveryAssumptionHasATitleAndANote() {
        for info in AssumptionInfo.allCases {
            XCTAssertFalse(info.title.isEmpty)
            XCTAssertGreaterThanOrEqual(info.paragraphs.count, 2, "\(info.title) says what it means, then how the date moves")
            XCTAssertFalse(info.paragraphs.contains(where: \.isEmpty))
        }
    }

    func testNotesShowTheDecidedDefaults() {
        let returns = "If you leave the three rates unset, they start at 3% bad, 6.5% typical, and 10% good. "
            + "Those are planning assumptions for a mix of developed-market stocks, before fees."
        for info in [AssumptionInfo.badReturn, .typicalReturn, .goodReturn] {
            XCTAssertEqual(info.paragraphs.last, returns)
        }
        XCTAssertTrue(AssumptionInfo.fee.paragraphs[0].contains("0.20% for an index ETF and 2.00% for a mutual fund"))
        XCTAssertTrue(AssumptionInfo.riskTolerance.paragraphs[0].hasSuffix("The starting value is 12 months."))
    }
}
