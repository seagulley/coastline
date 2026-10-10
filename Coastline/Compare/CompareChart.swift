import Charts
import SwiftUI

/// Net worth per option: a band from the bad to the good market, with the typical market as a line.
/// Dragging across the chart picks a year and lists each option's values for it.
struct CompareChart: View {
    let options: [CompareModel.Option]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(series) { series in
                    ForEach(series.points) { point in
                        AreaMark(
                            x: .value("Year", point.date),
                            yStart: .value("Bad market", point.plottedBad),
                            yEnd: .value("Good market", point.plottedGood),
                            series: .value("Option", series.title)
                        )
                        .foregroundStyle(by: .value("Option", series.title))
                        .opacity(0.2)

                        LineMark(
                            x: .value("Year", point.date),
                            y: .value("Typical market", point.plottedTypical),
                            series: .value("Option", series.title)
                        )
                        .foregroundStyle(by: .value("Option", series.title))
                    }
                }
                if let shown = shownYear {
                    RuleMark(x: .value("Year", shown.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: "CAD").notation(.compactName))
                        }
                    }
                }
            }
            .frame(height: 240)
            .accessibilityLabel("Net worth over time for each option, from a bad to a good market")

            if let shown = shownYear {
                YearReadout(year: shown, series: series, isScrubbing: selectedDate != nil)
            }
        }
    }

    private var series: [Series] {
        options.map { option in
            Series(title: option.title, points: Self.yearlyPoints(option.projection))
        }
    }

    /// The year nearest the drag, or the last year when nothing is selected.
    private var shownYear: YearPoint? {
        guard let points = series.first?.points, let last = points.last else { return nil }
        guard let selectedDate else { return last }
        return points.min { left, right in
            abs(left.date.timeIntervalSince(selectedDate)) < abs(right.date.timeIntervalSince(selectedDate))
        }
    }

    /// One point at the start and every 12 months after, plus the final month.
    /// Values are the engine's net worth in today's dollars; nothing is recalculated here.
    private static func yearlyPoints(_ projection: Projection) -> [YearPoint] {
        guard
            let typical = projection.scenario(.typical)?.months,
            let bad = projection.scenario(.bad)?.months,
            let good = projection.scenario(.good)?.months
        else { return [] }
        let count = min(typical.count, bad.count, good.count)
        guard count > 0 else { return [] }
        var indexes = Array(stride(from: 0, to: count, by: 12))
        if indexes.last != count - 1 {
            indexes.append(count - 1)
        }
        return indexes.compactMap { index in
            guard let date = PlanFormatting.firstDay(of: typical[index].month) else { return nil }
            return YearPoint(
                date: date,
                year: typical[index].month.year,
                bad: bad[index].netWorth,
                typical: typical[index].netWorth,
                good: good[index].netWorth
            )
        }
    }
}

private struct Series: Identifiable {
    let title: String
    let points: [YearPoint]

    var id: String { title }
}

private struct YearPoint: Identifiable {
    let date: Date
    let year: Int
    let bad: Decimal
    let typical: Decimal
    let good: Decimal

    var id: Date { date }

    /// Binary floating point for the chart axis only. The engine's amounts stay Decimal.
    var plottedBad: Double { NSDecimalNumber(decimal: bad).doubleValue }
    var plottedTypical: Double { NSDecimalNumber(decimal: typical).doubleValue }
    var plottedGood: Double { NSDecimalNumber(decimal: good).doubleValue }
}

private struct YearReadout: View {
    let year: YearPoint
    let series: [Series]
    let isScrubbing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isScrubbing ? "Net worth in \(String(year.year))" : "Net worth in \(String(year.year)). Drag the chart to see another year.")
                .font(.subheadline.weight(.semibold))
            ForEach(series) { series in
                if let point = series.points.first(where: { $0.date == year.date }) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(series.title)
                            .font(.caption.weight(.semibold))
                        Text("\(PlanFormatting.wholeCurrency(point.typical)) typical, \(PlanFormatting.wholeCurrency(point.bad)) to \(PlanFormatting.wholeCurrency(point.good))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
