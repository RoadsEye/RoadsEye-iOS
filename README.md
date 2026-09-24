# Road's Eye for iOS

Road's Eye turns the iPhone on your dash into a dashcam. It records continuously, clips the last stretch of driving on command, overlays speed and time, and can detect crashes and save footage automatically. No account and no subscription are required.

The App Store listing and roadseye.com close on **October 1, 2026**. This repository is the full source for the final release (3.2.0), published so anyone can build it, learn from it, or keep it going.

> **Project status:** Road's Eye is discontinued. From now on there will most likely be **no more updates**, bug fixes or support. Any future news will be posted in this repository, so check here for more info.

> **Heads up:** some parts of the original app were removed to prepare the code for open source. Some bugs or errors may have been introduced along the way and might not have been caught. If something doesn't work as expected, that could be why, so please test your own builds carefully.

---

## Features

- **Continuous recording** in segments, with automatic cleanup of old footage
- **Clip it**: save the last 30 seconds to 3 minutes with a tap (or a voice command)
- **Crash detection** using motion and speed data, with automatic saving
- **Speed and time overlay** on recorded video (mph or km/h)
- **Siri and Shortcuts** support: "Start recording", "Stop recording", "Clip it"
- **Auto-record** when driving starts
- Frame rate (including 60 fps), resolution and zoom settings
- Saves to the app's own folder (visible in the Files app) and optionally to Photos
- Light, dark, and system appearance

---

## Requirements

| | |
|---|---|
| **Mac** | macOS that runs a current Xcode |
| **Xcode** | 16 or newer (the project uses Xcode's synchronized folders) |
| **iOS** | 17.6 or newer |
| **iPhone** | Required. Road's Eye is a dashcam app, so it needs a real iPhone's camera and sensors. The Simulator can only show the interface. |
| **Apple Developer team** | Any, including the free personal team that comes with an Apple Account |

There are no third-party dependencies, so there's nothing to install: open the project and run.

---

## Getting started

### 1. Get the code

```bash
git clone https://github.com/RoadsEye/RoadsEye-iOS.git
cd RoadsEye-iOS
open RoadsEye.xcodeproj
```

Or, in Xcode: **File → Clone…**, paste `https://github.com/RoadsEye/RoadsEye-iOS.git`, and choose a folder.

### 2. Set up signing

Your team and bundle ID go in a small personal file that git ignores, so they never end up in a commit. A free personal team works: the app uses no paid-only capabilities.

1. **Add your Apple Account to Xcode** if you haven't: **Xcode → Settings → Accounts → +**, then sign in.
2. **Find your team ID:** in that same Accounts window, select your account. Your team is listed with a 10-character ID, for example `ABCDE12345`. (You can also find it by opening the **Team** menu in **Signing & Capabilities**.)
3. **Create your personal signing file.** In Terminal, from the project folder:

   ```bash
   cp Signing.local.xcconfig.example Signing.local.xcconfig
   ```

4. **Edit `Signing.local.xcconfig`** in any text editor:

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   APP_BUNDLE_ID = com.yourname.roadseye
   ```

   The bundle ID can be anything in reverse-domain style, as long as it's unique to you. The default in `Signing.xcconfig` is a placeholder and won't sign for a real device.

5. **Close and reopen the project** in Xcode. **Signing & Capabilities** should now show your team with no errors.

> Don't pick the team or change the bundle ID in the **Signing & Capabilities** tab itself. Xcode would save them into the shared project file (which gets committed) instead of your personal file.

### 3. Run it on your iPhone

1. Plug your iPhone in with a cable (or pair it over Wi-Fi in **Window → Devices and Simulators**).
2. On the phone, tap **Trust** when asked to trust this computer.
3. **Turn on Developer Mode** (iOS 16 and later): **Settings → Privacy & Security → Developer Mode**, switch it on, and restart when asked.
4. At the top of the Xcode window, click the device menu (next to the **RoadsEye** scheme name) and pick your iPhone.
5. Press **⌘R** (or the ▶︎ Run button).
6. The first time, iOS will refuse to open the app from an "Untrusted Developer". On the phone go to **Settings → General → VPN & Device Management**, tap your developer account, and tap **Trust**. Then press **⌘R** again.

> **Free personal team note:** apps signed with a free personal team stop opening after **7 days**. Just plug in and press ⌘R again to re-install; your recordings and settings are kept. A paid Apple Developer Program membership extends this to a year.

### 4. The Simulator (interface only)

The Simulator can't record, since it has no camera or motion sensors. It's still handy for working on the interface: pick any iPhone simulator from the device menu and press **⌘R** to try onboarding, settings and the legal screens.

---

## Everyday Xcode tips

| Action | Shortcut |
|---|---|
| Build and run | **⌘R** |
| Stop the running app | **⌘.** |
| Build only (check for errors) | **⌘B** |
| Run the tests | **⌘U** |
| Clean the build folder (fixes many odd errors) | **⇧⌘K** |
| Open a file by name | **⇧⌘O** |
| Search the whole project | **⇧⌘F** |
| Show/hide the debug console | **⇧⌘Y** |

- **Log output** (`print(...)` messages) appears in the console at the bottom of Xcode while the app runs.
- **SwiftUI previews:** open a view file that has a `#Preview` at the bottom and press **⌥⌘↩** to show the canvas. `OnboardingView` and `OpenSourceNoticeView` are good ones to try.
- **Adding files:** the `RoadsEye` folder is synchronized with Xcode, so any `.swift` file you create in it (from Xcode or Finder) is automatically part of the app.

### Building from the command line

```bash
xcodebuild -project RoadsEye.xcodeproj -scheme RoadsEye -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

---

## Project layout

```
RoadsEye/
├── RoadsEyeApp.swift            App entry point and launch flow
│                                (Onboarding → Terms → Main app → announcement)
├── Views/
│   ├── MainView.swift           Main camera screen
│   ├── MainViewModel.swift
│   ├── CameraView.swift         Camera preview
│   └── ControlButtonsView.swift Record / clip / settings buttons
├── SettingsSections/            One file per section of the Settings screen
├── RecordingManager.swift       Camera capture, segmented recording, clip snapshots
├── AssetWriterManager.swift     Writes video frames and the overlay to disk
├── ClippingManager.swift        Trims a snapshot down to the chosen clip length
├── VideoFileManager.swift       Folders, saving to Photos, cleanup
├── CrashDetectionManager.swift  Motion and speed based crash detection
├── LocationSpeedManager.swift   GPS speed and units
├── AutoRecordManager.swift      Starts recording when driving is detected
├── VoiceCommandManager.swift    Siri / Shortcuts intents
├── OnboardingView.swift         First-launch tutorial
├── TermsAcceptanceOverlay.swift Terms and privacy acceptance
├── OpenSourceNoticeView.swift   "Now open source" announcement
├── LegalDocumentsView.swift     In-app reader for the Terms and Privacy Policy
└── ToS.txt / PrivacyPolicy.txt  Legal text shown inside the app
RoadsEyeTests/, RoadsEyeUITests/ Test targets
Signing.xcconfig                 Shared signing defaults (don't edit)
Signing.local.xcconfig.example   Template for your personal signing file
```

---

## Permissions the app asks for

Road's Eye asks for permissions only after the Terms are accepted. Each one is described in the project's build settings (search for `INFOPLIST_KEY_NS` in the RoadsEye target).

| Permission | Why |
|---|---|
| Camera | Recording video |
| Microphone | Recording audio (optional) |
| Speech recognition | Voice commands |
| Location | Speed overlay, auto-record and crash detection |
| Motion | Crash detection |
| Photos (add) | Saving clips to your library |
| Notifications | Letting you know when videos are saved |

---

## Privacy

Road's Eye has no analytics, ads, accounts or servers. Recordings stay on the device (in the app's folder and, if you choose, your Photos library). There are no third-party dependencies: the app is built entirely on Apple's frameworks, so there are no packages to download.

---

## Contributing

The project is no longer maintained, so issues and pull requests may never be reviewed or answered. The best way to keep Road's Eye going is to fork it and build on it yourself.

1. Fork the repository and create a branch for your change.
2. Make sure it builds (**⌘B**) and, if you touched recording, test it on a real device.
3. Open a pull request describing what changed and why.

Please never commit signing settings, your own bundle identifier, or any API keys or config files.

---

## Disclaimer

Road's Eye and its source code are provided **"as is", without warranty of any kind**, express or implied, including fitness for a particular purpose. The entire risk of using, building, modifying or distributing the app or this code is yours. To the maximum extent permitted by law, the creators and contributors are **not liable** for any claim, damages or other liability, including lost or corrupted recordings, missed or false crash detections, accidents, injury, or any use of recordings as evidence.

Road's Eye is **not a safety or emergency device**. Never interact with it while driving, and never rely on it to detect a crash or contact help.

Builds made or modified by anyone else are not reviewed, endorsed or supported by Road's Eye. The full terms are in [RoadsEye/ToS.txt](RoadsEye/ToS.txt) and [RoadsEye/PrivacyPolicy.txt](RoadsEye/PrivacyPolicy.txt), which are also shown inside the app.

---

## License

The source code is released under the [MIT License](LICENSE). You're free to use, copy, modify and distribute it, as long as the license notice is kept.

The MIT License covers the code only. The Road's Eye name and logo are not included (see Trademark below).

---

## Trademark

"Road's Eye" and the Road's Eye logo are the names and branding of the original app. If you publish your own build to the App Store, please give it a different name and icon.

---

## Acknowledgements

The move to open source was done with help from [Claude](https://claude.com/claude-code), Anthropic's AI assistant. Claude helped remove sensitive information and the ads, analytics and subscription code, fix bugs found along the way, write this README, and update the Terms of Service and Privacy Policy for the open-source release.
