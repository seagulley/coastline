import Foundation

/// Runs one option through a good, typical, and bad market.
/// Screens and the recommendation read only `ScenarioOutcomes`, so Monte Carlo or historical replay can replace
/// `FixedReturnScenarios` without changing them. A random source must use a fixed seed: the same input has to
/// give the same outcomes, or results jitter while the split slider moves.
public protocol ScenarioSource: Sendable {
    /// `input.scenario` is ignored. The source runs every scenario itself.
    func outcomes(for input: ProjectionInput) -> ScenarioOutcomes
}

public struct ScenarioOutcomes: Hashable, Sendable {
    public var good: ProjectionResult
    public var typical: ProjectionResult
    public var bad: ProjectionResult

    public init(good: ProjectionResult, typical: ProjectionResult, bad: ProjectionResult) {
        self.good = good
        self.typical = typical
        self.bad = bad
    }

    public subscript(scenario: ProjectionScenario) -> ProjectionResult {
        switch scenario {
        case .good:
            return good
        case .typical:
            return typical
        case .bad:
            return bad
        }
    }
}

/// The fixed annual returns in `Assumptions`. Each option is simulated once per scenario.
public struct FixedReturnScenarios: ScenarioSource {
    public init() {}

    public func outcomes(for input: ProjectionInput) -> ScenarioOutcomes {
        func run(_ scenario: ProjectionScenario) -> ProjectionResult {
            var input = input
            input.scenario = scenario
            return ProjectionEngine.project(input)
        }
        return ScenarioOutcomes(good: run(.good), typical: run(.typical), bad: run(.bad))
    }
}
