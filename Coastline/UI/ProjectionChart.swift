import Charts
import SwiftUI

/// Plots net worth the engine already produced. Swift Charts draws it; this view does not compute it.
struct ProjectionChart: View {
    let projection: Projection

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Month", point.date),
                y: .value("Net worth", point.netWorth)
            )
            .foregroundStyle(by: .value("Scenario", point.scenario.title))
        }
        .accessibilityLabel("Net worth over time")
    }

    private var points: [PlotPoint] {
        projection.scenarios.flatMap { scenario in
            scenario.months.compactMap { month in
                guard let date = date(for: month.month) else { return nil }
                return PlotPoint(
                    scenario: scenario.scenario,
                    date: date,
                    netWorth: NSDecimalNumber(decimal: month.netWorth).doubleValue
                )
            }
        }
    }

    private func date(for month: YearMonth) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1))
    }
}

private struct PlotPoint: Identifiable {
    let scenario: ReturnScenario
    let date: Date
    /// Binary floating point for the chart axis only. The engine's amount stays a Decimal.
    let netWorth: Double

    var id: String {
        "\(scenario.rawValue)-\(date.timeIntervalSince1970)"
    }
}
