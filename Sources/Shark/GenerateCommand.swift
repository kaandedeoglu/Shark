import Foundation
import ArgumentParser
import SharkKit

struct Generate: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(commandName: "generate",
                                                           abstract: "Generate the resource enums (default). Paste the following line in a Xcode run phase script that runs before the \"Compile Sources\" run phase:",
                                                           discussion: "shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME")

    @OptionGroup()
    private var options: Options

    func run() async throws {

        let enumString = try await SharkEnumBuilder.sharkEnumString(forOptions: options)
        var lastContent: String = ""
        if let data = try? Data(contentsOf: URL(fileURLWithPath: options.outputPath)),
           let content = String(data: data, encoding: .utf8) {
            lastContent = content
        }
        let newContent = FileBuilder.fileContents(with: enumString, options: options)
        guard newContent != lastContent else { return }
        try newContent.write(to: URL(fileURLWithPath: options.outputPath), atomically: true, encoding: .utf8)
    }
}
