import ArgumentParser
import SharkKit

@main
struct Shark: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(abstract: "Generates type-safe Swift enums for Xcode project resources",
                                                           subcommands: [Generate.self, Lint.self],
                                                           defaultSubcommand: Generate.self)
}
