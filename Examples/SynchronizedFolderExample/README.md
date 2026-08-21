# SynchronizedFolderExample

An Xcode 16 folder-backed target: the sources and resources are not listed in the project file at
all, they are a `PBXFileSystemSynchronizedRootGroup` whose membership follows the file system.

This is the shape that made Shark blind in issue #50 and drove the move to XcodeGraph in #51. Shark
resolves it itself again, so this fixture guards the walk — including the membership exception that
keeps `Excluded.xcassets` out of the target.
