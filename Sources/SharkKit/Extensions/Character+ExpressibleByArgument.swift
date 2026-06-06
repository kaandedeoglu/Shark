import ArgumentParser

#if hasFeature(RetroactiveAttribute)
extension Character: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        guard argument.count == 1 else {
            return nil
        }
        self = argument.first!
    }
}
#else
extension Character: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        guard argument.count == 1 else {
            return nil
        }
        self = argument.first!
    }
}
#endif
