# Shark
Swift CLI to transform the .xcassets folder into a type safe enum

###How to run:

- Switch to Xcode Beta toolchain - sudo xcode-select -switch /Applications/Xcode-beta.app/Contents/Developer/

There are 2 ways to run:

1. swift Shark.swift -F ./Rome [PATH-TO-.ImageAssets-FOLDER] [OUTPUT-DIRECTORY]
  
**OR**

2. move shark executable to /usr/local/bin and call shark [PATH-TO-.ImageAssets-FOLDER] [OUTPUT-DIRECTORY]


###How to Build an executable:

- xcrun -sdk macosx swiftc -F ./Rome Shark.swift -o shark
