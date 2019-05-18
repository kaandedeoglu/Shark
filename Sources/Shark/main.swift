let parseResult = try Parser.parse()
let enumString = try SharkEnumBuilder.sharkEnumString(forParseResult: parseResult)

try FileBuilder
    .fileContents(with: enumString, filename: parseResult.outputURL.lastPathComponent)
    .write(to: parseResult.outputURL, atomically: true, encoding: .utf8)
