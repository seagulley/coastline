import SwiftUI

/// What the user confirmed in Compare, with the engine's projection from before and after.
struct Choice {
    var summary: String
    var before: Projection
    var after: Projection
}

/// Opens after I'll do this is confirmed. Shows the choice and how it moved the Coast FIRE date.
struct AfterChoosingView: View {
    let choice: Choice

    var body: some View {
        List {
            Section("Your choice") {
                Text(choice.summary)
            }
            Section("Coast FIRE date, typical market") {
                LabeledContent("Before", value: date(choice.before.scenario(.typical)?.coastFireDate))
                LabeledContent("After", value: date(choice.after.scenario(.typical)?.coastFireDate))
            }
            Section("After, good to bad market") {
                LabeledContent("Good market", value: date(choice.after.scenario(.good)?.coastFireDate))
                LabeledContent("Bad market", value: date(choice.after.scenario(.bad)?.coastFireDate))
            }
            Section {
                Text("Saved on this device.")
            }
        }
        .navigationTitle("After choosing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func date(_ date: CalendarDate?) -> String {
        date.map(PlanFormatting.monthAndYear) ?? "Not reached before retirement"
    }
}
