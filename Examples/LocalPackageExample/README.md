# LocalPackageExample

A project that links a local Swift package the way Xcode writes it: once as an
`XCLocalSwiftPackageReference`, and once as a plain folder reference so the package shows up in the
project navigator.

XcodeGraph collects local packages from both places, keys them by path, and requires those keys to
be unique — the duplicate aborted the process (`Fatal error: Duplicate values for key`) instead of
raising an error Shark could catch. Shark now detects the duplicate and maps a de-duplicated copy of
the project, which is what this fixture guards.

Upstream report: https://github.com/tuist/tuist/issues/12546
