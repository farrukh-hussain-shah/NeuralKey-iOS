# Neural Key — iOS

Native iOS app and custom keyboard extension for Neural Key AI Keyboard.

**Status: Phase 1 (onboarding) implemented.** Home, Settings, Premium, Firebase and the AI
keyboard toolbar are Phase 2.

> **Verification status.** Built and tested in the cloud (GitHub Actions, Xcode 26.6,
> iPhone 17 Pro simulator on iOS 26.5): the app, keyboard extension and tests compile with
> no errors or compiler warnings, 21 unit tests and 6 UI tests pass, and every onboarding
> screen has been reviewed from Simulator screenshots. **Not yet tested on a real iPhone**:
> the keyboard itself and the Full Access states need a device (TestFlight).

## Requirements

- Xcode 16 or later
- iOS 16.0+ deployment target, iPhone only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Developer team with an **App Group** enabled (keyboard ⇄ app communication)

## First-time setup

1. Open `Config/Shared.xcconfig` and set `DEVELOPMENT_TEAM`. Confirm `APP_BUNDLE_ID`
   (currently mirrors the Android package — an assumption to verify).
2. In the Apple Developer portal, register the App Group `group.<APP_BUNDLE_ID>` and
   enable it for both the app ID and the keyboard extension ID
   (or let Xcode's automatic signing do it on first build).
3. Generate and open the project:

   ```sh
   xcodegen generate
   open NeuralKey.xcodeproj
   ```

4. Run the `NeuralKey` scheme. Tests: `⌘U`.

The `.xcodeproj` is generated and git-ignored; `project.yml` is the source of truth.

### No Mac? Build in the cloud

`.github/workflows/ios.yml` builds the app on a GitHub-hosted Mac on every push: it
generates the project, compiles app + keyboard + tests, runs the unit tests, then runs
`NeuralKeyUITests` to capture a screenshot of each onboarding screen in the Simulator.
Logs and screenshots are attached to the run as the `neural-key-ios-results` artifact.

The `.github` folder must be at the top level of the repository. The workflow needs no
Apple account. It cannot test the keyboard on a real phone or the Full Access states;
those need TestFlight and a paid Apple Developer membership.

(Google Cloud Build cannot build iOS apps: it has no macOS machines.)

### Optional: brand font

The designs use **Space Grotesk**. Add the static TTFs (Regular, Medium, SemiBold, Bold)
to `NeuralKey/Resources/Fonts/` and list them under `UIAppFonts` in
`Config/NeuralKey-Info.plist`. `NKTypography` picks them up automatically; until then the
system font is used at the same sizes.

## Structure

```
Config/                 xcconfig, Info.plists, entitlements (one place for identifiers)
Shared/                 Compiled into BOTH targets. Foundation only.
  AppGroup              App Group + bundle identifiers read from Info.plist
  KeyboardSharedState   What the keyboard reports to the app (active, Full Access)
  DarwinNotifier        "State changed" ping between the two processes
NeuralKey/              App target (SwiftUI)
  App/                  Entry point, AppState (routing + services), RootView
  DesignSystem/         Tokens (colour, type, spacing) and reusable components
  Services/             Keyboard setup detection, Settings link, analytics seam, links
  Features/
    Splash/             Launch screen content
    Onboarding/         Flow rules, view model, steps, illustrations, troubleshooting
    Home/               TEMPORARY placeholder until Phase 2
NeuralKeyKeyboard/      Keyboard extension target (UIKit, UIInputViewController)
NeuralKeyTests/         Unit tests for flow rules, detection, shared state, view model
NeuralKeyUITests/       Simulator walkthrough that captures onboarding screenshots
.github/workflows/      Cloud build on a GitHub-hosted Mac
```

## Onboarding flow

| # | Screen | Purpose | Exits |
|---|--------|---------|-------|
| 0 | Splash | Brand moment, ~1 s | auto |
| 1 | Intro (3 pages) | Improve, Translate, Tone | Continue / Skip |
| 2 | Add Neural Key (step 1 of 3) | Enable the keyboard in Settings | Open Settings → auto-detected → Continue; manual "I've already added it" if detection fails |
| 3 | Full Access (step 2 of 3) | Explain why, what is sent, expected iOS warning | Open Settings / **Not now** |
| 4 | Switch & try (step 3 of 3) | Globe key, test field; confirms Full Access live | Continue (never blocked) |
| 5 | All set | Summary, limitations, fix-it link | Start Using Neural Key |
| – | Setup Help | FAQ, manual Settings path, support email | from every setup step |

Progress is saved after every step, so a user whose app is terminated while they are in
Settings resumes where they left off.

## iOS platform rules this design is built around

- **No direct deep link to keyboard settings.** `UIApplication.openSettingsURLString`
  opens *Settings › Neural Key*, where the **Keyboards** row holds both switches. Private
  `App-prefs:` URLs are not used (App Review rejection).
- **Is the keyboard enabled?** There is no public API. `KeyboardSetupMonitor` reads the
  `AppleKeyboards` global default — undocumented but long-standing and widely shipped.
  It is treated as a hint; the manual "I've already added it" path means a change in iOS
  can never trap a user.
- **Is Full Access on?** Only the extension knows (`hasFullAccess`). It writes the answer
  to the App Group when it appears. Without Full Access iOS blocks that write, so the app
  shows "not confirmed yet" rather than guessing. A later *revocation* therefore cannot be
  seen by the app; the keyboard checks `hasFullAccess` live and shows its own notice.
- **Full Access is optional.** The keyboard must work without it (Guideline 4.4.1), hence
  "Not now" and a fully functional typing experience offline.
- **Password fields and some apps** always use the system keyboard. The completion screen
  and Help say so, to prevent "it's broken" support requests.
- **The keyboard has no supported way to open the containing app or Settings.** Its Full Access notice is
  informational only.

## Decisions to confirm with the team

| Topic | Current value | Why it needs confirming |
|-------|---------------|-------------------------|
| iOS bundle ID | `com.neuralkey.aikeyboard` | Assumed from the Android package |
| Terms of Use URL | Apple standard EULA | No Neural Key terms URL was supplied |
| Product name in UI | "Neural Key" | Boards say "NeuralKey", "NeuralBoard" and "AI Keyboard" in different places |
| Onboarding chips | Private / Fast / Any app | The board's "Offline – Local Mode" would be inaccurate: AI features need a connection |
| Splash loading text | Kept as designed | "Initializing neural networks… 84%" is decorative; consider removing |
| Analytics event names | `onboarding_*` | Should match Android's existing Firebase events |
| Appearance | Dark only | Light / System arrive with Settings in Phase 2 |

## Device test checklist (Phase 1)

Run on a real iPhone — the Simulator does not reproduce Full Access behaviour faithfully.

- [ ] Fresh install → splash → intro pages swipe and Continue; Skip jumps to setup.
- [ ] "Open Settings" lands on *Settings › Neural Key* and shows a **Keyboards** row.
- [ ] Turning on Neural Key and returning flips step 1 to "Neural Key is added".
- [ ] Kill the app while in Settings; relaunch resumes on the same step.
- [ ] Full Access: iOS warning appears; after Allow, the try step shows
      "Neural Key is active" once the keyboard is opened.
- [ ] "Not now" path: typing works, the keyboard shows the Full Access notice,
      completion screen shows "AI features are off".
- [ ] Remove the keyboard in Settings mid-flow → app returns to step 1.
- [ ] Globe key: tap switches keyboard, touch-and-hold shows the list.
- [ ] Password field → system keyboard appears (expected).
- [ ] iPhone SE (small) and Pro Max (large); Dynamic Type at the largest size;
      VoiceOver through the whole flow; Reduce Motion on.
- [ ] Fast two-thumb typing never drops characters; hold-to-delete repeats.
