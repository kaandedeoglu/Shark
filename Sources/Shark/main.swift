let parseResult = try Parser.parse()
let enumString = try SharkEnumBuilder.sharkEnumString(forParseResult: parseResult)
try FileBuilder.fileContents(with: enumString, filename: parseResult.fileName).write(to: parseResult.outputURL, atomically: true, encoding: .utf8)
