# Shark

![Build](https://github.com/kaandedeoglu/Shark/workflows/Swift/badge.svg)

Shark is a Swift command line tool that generates type safe enums for your images, colors, storyboards, fonts and localizations.
Shark supports code generation for `UIKit`, `AppKit`, and `SwiftUI`.

Because Shark reads your `.xcodeproj` to find these assets, the setup is extremely simple.

## Motivation

Here's what a generated `Shark.swift` file for `UIKit` looks like and how it is used in a codebase:

```swift
// Shark.swift
// Generated by Shark https://github.com/kaandedeoglu/Shark

import UIKit

// swiftlint:disable all
public enum Shark {
    private static let bundle: Bundle = {
        class Custom {}
        return Bundle(for: Custom.self)
    }()

    public enum I {
        public enum Button {
            public static var profile: UIImage { return UIImage(named:"profile", in: bundle, compatibleWith: nil)! }
            public static var cancel: UIImage { return UIImage(named:"cancel", in: bundle, compatibleWith: nil)! }
            public static var user_avatar: UIImage { return UIImage(named:"user_avatar", in: bundle, compatibleWith: nil)! }
        }
    }

    public enum C {
        public static var blue1: UIColor { return UIColor(named: "blue1", in: bundle, compatibleWith: nil)! }
        public static var blue2: UIColor { return UIColor(named: "blue2", in: bundle, compatibleWith: nil)! }
        public static var gray1: UIColor { return UIColor(named: "gray1", in: bundle, compatibleWith: nil)! }
        public static var gray2: UIColor { return UIColor(named: "gray2", in: bundle, compatibleWith: nil)! }
        public static var green1: UIColor { return UIColor(named: "green1", in: bundle, compatibleWith: nil)! }
        public static var green2: UIColor { return UIColor(named: "green2", in: bundle, compatibleWith: nil)! }
    }

    public enum F {
        public static func gothamBold(ofSize size: CGFloat) -> UIFont { return UIFont(name: "Gotham-Bold", size: size)! }
        public static func gothamMedium(ofSize size: CGFloat) -> UIFont { return UIFont(name: "Gotham-Medium", size: size)! }
        public static func gothamRegular(ofSize size: CGFloat) -> UIFont { return UIFont(name: "Gotham-Regular", size: size)! }
    }

    public enum L {
        public enum button {
            /// Login
            public static var login: String { return NSLocalizedString("button.login", bundle: bundle, comment: "") }

            /// Logout
            public static var logout: String { return NSLocalizedString("button.logout", bundle: bundle, comment: "") }
        }

        public enum login {
            /// Please log in to continue
            public static var title: String { return NSLocalizedString("login.title", bundle: bundle, comment: "") }

            /// Skip login and continue
            public static var skip: String { return NSLocalizedString("login.skip", bundle: bundle, comment: "") }

            public enum error {
                /// Login failed
                public static var title: String { return NSLocalizedString("login.error.title", bundle: bundle, comment: "") }

                /// Operation failed with error: %@
                public static func message(_ value1: String) -> String {
                    return String(format: NSLocalizedString("login.error.message", bundle: bundle, comment: ""), value1)
                }
            }
        }
    }
}

// At the call site
imageView.image = Shark.I.Button.profile
label.font = Shark.F.gothamBold(ofSize: 16.0)
label.text = Shark.L.login.title
view.backgroundColor = Shark.C.green1

// You can also make it prettier with typealiases
typealias I = Shark.I
typealias C = Shark.C
typealias F = Shark.F
typealias L = Shark.L

imageView.image = I.Button.profile
label.font = F.gothamBold(ofSize: 16.0)
label.text = L.login.error.message("I disobeyed my masters")
view.backgroundColor = C.green1
```

There are a few things to notice:

First, have a look at this Xcode screenshot from the inspector pane of an asset catalogue's folder entry:

![](https://user-images.githubusercontent.com/167469/190901709-d4cf52f9-43bb-4c5e-bc4e-dfce24dd2638.png)

If you place your image and color assets in folders, Shark will create namespaced `enum`s ­– provided you have configured the respective Xcode setting _Provides Namespace_. If you have deeply nested folders, Shark will respect every one's individual namespace setting.

Localizations are always namespaced with separators. Currently Shark uses the dot symbol `.` as the separator.
  As you can see localization keys are recursively namespaced until we get to the last component.

## Installation

### Homebrew

```bash
brew install kaandedeoglu/formulae/shark
```

### Mint

```bash
mint install kaandedeoglu/formulae/shark
```

### Manually

Clone the project, then do:

```bash
> swift build -c release
> cp ./build/release/Shark /usr/local/bin
```

You can then verify the installation by doing

```bash
> shark --help
```

## Setup

- Add a new Run Script phase to your target's build phases. This build phase should ideally run before the `Compile Sources` phase. The script body should look like the following:

  ```bash
  if [ -x "$(command -v shark)" ]; then
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME/
  fi
  ```

  the `if/fi` block makes sure that Shark runs only if it's installed on the current machine.

- Build your project. You should now see a file named `Shark.swift` in your project folder.
- Add this file to your target. Voila! `Shark.swift` will be updated every time you build the project.
- Alternatively you can do the following:

  ```bash
  # Write to a specific file called MyAssets.swift
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME/MyAssets.swift
  ```

  ```bash
  # Write to a specific file in a different folder
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME/Utility/MyAssets.swift
  ```

## Options & Flags

Shark also accepts the following command line options to configure behavior

### --name

By default, the top level enum everything else lives under is called - you guessed it - `Shark`. You can change this by using the `--name` flag.

 ```bash
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --name Assets
  ```

### --locale

By default, Shark will try to find English localizations to generate the localizations enum. If there are no English `.strings` file in your project, or you'd like Shark to take another localization as base, you can specify the language code with the `--locale` flag.

 ```bash
# Use Spanish localizations for generation
shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --locale es
```

### --target

In case your Xcode project has multiple application targets, you should specify which one Shark should look at by using the `--target` flag.

   ```bash
shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --target MyAppTarget
```

### --visibility

By default, Shark will create all properties with the visibilty of `public`. Submit this option to change this to, e.g., `internal`.

### --framework

By default, Shark creates code for `UIKit`. Specify `--framework appkit` to create code for `AppKit`, and `--framework swiftui` for `SwiftUI`.

### --separator

Shark will split localization keys using the separator character value, and create nested enums until we hit the last element. For example, the lines `login.button.positive = "Log in!";` and `login.button.negative = "Go back...";` will create the following structure inside the top level localizations enum `L`:

```swift
public enum login {
    public enum button {
        public static var positive: String { return NSLocalizedString("login.button.positive") }
        public static var negative: String { return NSLocalizedString("login.button.negative") }
    }
}
```

By default, the separator is `.`, only single character inputs are accepted for this option.

### --top-level-scope

Declares the `I, C, F, L` enums in the top level scope instead of nesting it in a top level `Shark` enum.

### --help

Prints the overview, example usage and available flags to the console.

## License

The MIT License (MIT)

Copyright (c) Kaan Dedeoglu and contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
