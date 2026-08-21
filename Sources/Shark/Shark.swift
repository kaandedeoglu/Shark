import ArgumentParser
import SharkKit

@main
struct Shark: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(abstract: "Generates type-safe Swift enums for Xcode project resources",
                                                           version: "2.2.0-dev",
                                                           subcommands: [Generate.self, Lint.self, Translate.self],
                                                           defaultSubcommand: Generate.self)
}
