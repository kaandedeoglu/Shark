# Shark

[![Build Status](https://travis-ci.org/kaandedeoglu/Shark.svg?branch=master)](https://travis-ci.org/kaandedeoglu/Shark)

Shark is a Swift command line tool that generates type safe enums for your image assets, color assets, localizations and fonts.

Because Shark reads your .xcodeproj to find these assets, the setup is extremely simple.

## Installation

### Brew

```bash
brew install kaandedeoglu/formulae/shark
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
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME
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

## Options

Shark also accepts the following command line options to configure behavior

### --name

By default, the top level enum everything else lives under is called - you guessed it - `Shark`. You can change this by using the `--name` flag.

 ```bash
  shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --name Assets
  ```

### --locale

By default, Shark will try to find English localizations to generate the localizations enum. If there are no English .strings file in your project, or you'd like Shark to take another localization as base, you can specify the language code with the `--locale` flag.
 ```bash
# Use Spanish localizations for generation
shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --locale es
```

### --target

In case your Xcode project has multiple application targets, you should specify which one Shark should look at by using the `--target` flag.

   ```bash
shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME --target MyAppTarget
```

### --help

Prints the overview, example usage and available flags to the console.

## Sample output

Below is a sample output generated by Shark. As you can see, the top level `enum Shark` contains three enums inside. `I` (Images), `L` (Localizations) and `C` (Colors). Example usage looks like

```swift
// Generated by Shark
public enum Shark {
    private static let bundle: Bundle = {
        class Custom {}
        return Bundle(for: Custom.self)
    }()

    public enum I {
        public enum Button {
            public static var profile: UIImage { return UIImage(named:"report_user", in: bundle, compatibleWith: nil)! }
            public static var cancel: UIImage { return UIImage(named:"battery_swap_maintained", in: bundle, compatibleWith: nil)! }
            public static var user_avatar: UIImage { return UIImage(named:"damage_check", in: bundle, compatibleWith: nil)! }
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

```swift
imageView.image = Shark.I.TaskIcons.task_icon_clean
label.font = Shark.F.gothamBold(ofSize: 16.0)
label.text = Shark.L.button.login
view.backgroundColor = Shark.C.blue1
```

There are a few things to notice:

- Image assets are namespaced by folder. For example all the images in your `.xcassets` folder that are contained in a folder called `TaskIcons` will be listed under an enum called `TaskIcons`.
- Localizations are namespaced with separators. Currently Shark uses the dot symbol `.` as the separator.
  As you can see localization keys are recursively namespaced until we get to the last component.

```swift
public enum L {
    public enum button {
        /// Login
        public static var login: String { return NSLocalizedString("button.login", bundle: bundle, comment: "")) }

        /// Logout
        public static var logout: String { return NSLocalizedString("button.logout", bundle: bundle, comment: "")) }
    }
}
```

You can see an example `Shark.swift` below:

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
        public enum MapIcons {
            public static var battery_swap_available: UIImage { return UIImage(named:"battery_swap_available", in: bundle, compatibleWith: nil)! }
            public static var battery_swap_maintained: UIImage { return UIImage(named:"battery_swap_maintained", in: bundle, compatibleWith: nil)! }
            public static var damage_check: UIImage { return UIImage(named:"damage_check", in: bundle, compatibleWith: nil)! }
        }

        public enum TaskIcons {
            public static var task_icon_clean: UIImage { return UIImage(named:"task_icon_clean", in: bundle, compatibleWith: nil)! }
            public static var task_icon_fallback: UIImage { return UIImage(named:"task_icon_fallback", in: bundle, compatibleWith: nil)! }
            public static var task_icon_replacebatteries: UIImage { return UIImage(named:"task_icon_replacebatteries", in: bundle, compatibleWith: nil)! }
            public static var task_icon_replacezipper: UIImage { return UIImage(named:"task_icon_replacezipper", in: bundle, compatibleWith: nil)! }
        }

        public static var apple_maps: UIImage { return UIImage(named:"apple-maps", in: bundle, compatibleWith: nil)! }
        public static var back_image: UIImage { return UIImage(named:"back_image", in: bundle, compatibleWith: nil)! }
        public static var google_maps: UIImage { return UIImage(named:"google-maps", in: bundle, compatibleWith: nil)! }
        public static var icon_banner_retry: UIImage { return UIImage(named:"icon-banner-retry", in: bundle, compatibleWith: nil)! }
        public static var icon_battery_level: UIImage { return UIImage(named:"icon-battery-level", in: bundle, compatibleWith: nil)! }
        public static var icon_cancel_modal_cant_access: UIImage { return UIImage(named:"icon-cancel-modal-cant-access", in: bundle, compatibleWith: nil)! }
        public static var icon_cancel_modal_cant_find: UIImage { return UIImage(named:"icon-cancel-modal-cant-find", in: bundle, compatibleWith: nil)! }
    }

    public enum C {
        public static var backgroundColor: UIColor { return UIColor(named: "backgroundColor", in: bundle, compatibleWith: nil)! }
        public static var blue1: UIColor { return UIColor(named: "blue1", in: bundle, compatibleWith: nil)! }
        public static var blue2: UIColor { return UIColor(named: "blue2", in: bundle, compatibleWith: nil)! }
        public static var blue3: UIColor { return UIColor(named: "blue3", in: bundle, compatibleWith: nil)! }
        public static var gray1: UIColor { return UIColor(named: "gray1", in: bundle, compatibleWith: nil)! }
        public static var gray2: UIColor { return UIColor(named: "gray2", in: bundle, compatibleWith: nil)! }
        public static var gray3: UIColor { return UIColor(named: "gray3", in: bundle, compatibleWith: nil)! }
        public static var green1: UIColor { return UIColor(named: "green1", in: bundle, compatibleWith: nil)! }
        public static var green2: UIColor { return UIColor(named: "green2", in: bundle, compatibleWith: nil)! }
        public static var green3: UIColor { return UIColor(named: "green3", in: bundle, compatibleWith: nil)! }
        public static var red1: UIColor { return UIColor(named: "red1", in: bundle, compatibleWith: nil)! }
        public static var red2: UIColor { return UIColor(named: "red2", in: bundle, compatibleWith: nil)! }
        public static var red3: UIColor { return UIColor(named: "red3", in: bundle, compatibleWith: nil)! }
    }

    public enum F {
        public static func ibmPlexMono(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexMono", size: size)! }
        public static func ibmPlexMonoMedium(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexMono-Medium", size: size)! }
        public static func ibmPlexMonoSemibold(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexMono-SemiBold", size: size)! }
        public static func ibmPlexSans(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexSans", size: size)! }
        public static func ibmPlexSansBold(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexSans-Bold", size: size)! }
        public static func ibmPlexSansMedium(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexSans-Medium", size: size)! }
        public static func ibmPlexSansSemibold(ofSize size: CGFloat) -> UIFont { return UIFont(name: "IBMPlexSans-SemiBold", size: size)! }
    }

    public enum L {
        public enum banner {
            public enum generic {
                /// Error
                public static var title: String { return NSLocalizedString("banner.generic.title", bundle: bundle, comment: "") }
            }

            public enum invalid_credentials {
                /// Wrong email & password combination
                public static var title: String { return NSLocalizedString("banner.invalid_credentials.title", bundle: bundle, comment: "") }
            }

            public enum shift_end_failed {
                /// You have no more tickets, but ending your shift failed, please try again.
                public static var message: String { return NSLocalizedString("banner.shift_end_failed.message", bundle: bundle, comment: "") }

                /// Could not end your shift
                public static var title: String { return NSLocalizedString("banner.shift_end_failed.title", bundle: bundle, comment: "") }
            }
        }

        public enum button {
            /// Unlocking...
            public static var busy: String { return NSLocalizedString("button.busy", bundle: bundle, comment: "") }

            /// Cancel
            public static var cancel: String { return NSLocalizedString("button.cancel", bundle: bundle, comment: "") }

            /// Create
            public static var create: String { return NSLocalizedString("button.create", bundle: bundle, comment: "") }

            /// Done
            public static var done: String { return NSLocalizedString("button.done", bundle: bundle, comment: "") }
        }

        public enum error {
            public enum generic {
                /// Error
                public static var title: String { return NSLocalizedString("error.generic.title", bundle: bundle, comment: "") }
            }

            public enum location_required {
                /// Turn on location services to allow Runner to determine your location
                public static var message: String { return NSLocalizedString("error.location_required.message", bundle: bundle, comment: "") }

                /// Location required
                public static var title: String { return NSLocalizedString("error.location_required.title", bundle: bundle, comment: "") }
            }

            public enum unlock {
                public enum battery {
                    /// Unlocking the scooter failed due to a battery error, please retry or open the trunk to proceed to the tasks screen
                    public static var message: String { return NSLocalizedString("error.unlock.battery.message", bundle: bundle, comment: "") }
                }

                public enum battery_levels {
                    /// Unlock succeeded, but reporting battery levels failed, please try again
                    public static var message: String { return NSLocalizedString("error.unlock.battery_levels.message", bundle: bundle, comment: "") }
                }

                public enum general {
                    /// Unlocking the scooter failed, please retry or open the trunk to proceed to the tasks screen
                    public static var message: String { return NSLocalizedString("error.unlock.general.message", bundle: bundle, comment: "") }
                }

                public enum generic {
                    /// Unlock failed, please try again
                    public static var message: String { return NSLocalizedString("error.unlock.generic.message", bundle: bundle, comment: "") }

                    /// Unlock failed
                    public static var title: String { return NSLocalizedString("error.unlock.generic.title", bundle: bundle, comment: "") }
                }
            }

            /// Not a valid email address
            public static var invalid_email: String { return NSLocalizedString("error.invalid_email", bundle: bundle, comment: "") }

            /// Password must be at least 8 characters
            /// include upper and lowercase letters,
            /// numbers and special characters
            public static var invalid_password: String { return NSLocalizedString("error.invalid_password", bundle: bundle, comment: "") }

            /// Starting Runner failed with error: %@
            public static func loading_failed(_ value1: String) -> String {
                return String(format: NSLocalizedString("error.loading_failed", bundle: bundle, comment: ""), value1)
            }
        }
    }
}
```

## License

The MIT License (MIT)

Copyright (c) 2020 Kaan Dedeoglu

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
