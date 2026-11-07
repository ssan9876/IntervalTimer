# Intervals: App Store submission

Everything App Store Connect asks for, ready to paste, plus the steps only you can do.
Checked against Apple's App Review Guidelines, upcoming requirements and screenshot specifications, November 6, 2026.

**Public pages (GitHub Pages)**
- Marketing: https://ssan9876.github.io/intervals-site/
- Privacy policy URL: https://ssan9876.github.io/intervals-site/privacy/
- Support URL: https://ssan9876.github.io/intervals-site/support/
- Support email: intervaltimersupport@gmail.com

**Identifiers**
- Bundle ID: `com.sethsander.intervals` (widget: `com.sethsander.intervals.widget`)
- SKU: `intervals-ios`
- Team ID: `H7AQLZT93R`

---

## 1. Your steps, in order

1. **Register the bundle ID**: developer.apple.com/account > Certificates, IDs & Profiles > Identifiers > +. App IDs > App. Description `Intervals`, Explicit, `com.sethsander.intervals`. No capabilities need ticking.
2. **Create the app record**: App Store Connect > Apps > + > New App.
   - Platform: iOS. Name: `Intervals: Timer & Log`. Primary language: English (U.S.).
   - Bundle ID: `com.sethsander.intervals`. SKU: `intervals-ios`. User access: Full Access.
   - If Apple says the name is taken, try `Intervals: Timer & Daily Log`.
3. **Add the API key to this repo**. GitHub secrets belong to one repo and can't be read back, so the Kinbook ones have to be entered again. You can reuse the same key: run these in a terminal, and paste each value when asked. The first two are on App Store Connect > Users and Access > Integrations > Team Keys.
   ```
   gh secret set ASC_KEY_ID -R ssan9876/IntervalTimer
   gh secret set ASC_ISSUER_ID -R ssan9876/IntervalTimer
   gh secret set ASC_KEY_P8 -R ssan9876/IntervalTimer < "path/to/AuthKey_XXXXXXXXXX.p8"
   ```
   If you no longer have the `.p8` file, make a new key there with the **Admin** role. Apple only lets you download it once. Kinbook keeps working with its old key.
4. **Check your EU trader status**: App Store Connect > Business. Apple requires a declaration even for free apps, and it applies to your whole account, so it may be done already from Kinbook. If you declare yourself a trader, your address, phone number and email appear publicly on your product pages. It's your legal call, so ask an advisor if you're unsure.
5. **Build and upload**: github.com/ssan9876/IntervalTimer > Actions > iOS > Run workflow. About 15 minutes later the build appears in App Store Connect > TestFlight.
6. **Test on your iPhone and iPad** through TestFlight, using the checklist in section 6.
7. **Record the audio demo** described in section 5. It's your best protection against a rejection under guideline 2.5.4.
8. **Screenshots**: see section 4.
9. **Fill in App Store Connect** with sections 2, 3 and 5, choose the build, and press **Submit for Review**.

---

## 2. App information (paste these)

| Field | Value | Limit |
| --- | --- | --- |
| Name | Intervals: Timer & Log | 30 |
| Subtitle | Workouts, tasks and progress | 30 |
| Primary category | Health & Fitness | |
| Secondary category | Productivity | |
| Copyright | 2026 Seth Sander | |
| Support URL | https://ssan9876.github.io/intervals-site/support/ | |
| Marketing URL | https://ssan9876.github.io/intervals-site/ | |
| Privacy policy URL | https://ssan9876.github.io/intervals-site/privacy/ | |
| Price | Free | |

**Promotional text** (170 characters, can change any time without review)

```
Build interval timers for workouts and daily tasks, hear every change with your phone locked, and see your progress add up day by day and month by month.
```

**Keywords** (100 characters, comma-separated, no spaces needed)

```
hiit,workout,circuit,boxing,round,rest,focus,study,meditation,routine,streak,habit,tracker,exercise
```

"Tabata" and "Pomodoro" are left out on purpose. Both are names people associate with someone else's method or brand, and guideline 2.3.7 warns against trademarked terms in metadata. The app's sample timers avoid them too.

**Description** (4,000 characters)

```
Intervals is a timer for anything you do in rounds: a hard workout, a focus session, the daily chores or ten quiet minutes. Set it up once, press play, and let each interval roll into the next while your progress adds up.

TIMERS THAT RUN THEMSELVES
Give each interval a name, a length and a color, then choose how many rounds to repeat. Start from a template for an interval workout, focus sessions, a daily task or meditation. Pause, skip forward or go back whenever you need to.

HEAR EVERY CHANGE
3-2-1 beeps and a cue at each new interval, played over your music without pausing it and with your iPhone locked. Choose from Classic, Bell, Digital or Soft Chime, have each interval's name read aloud, or import your own audio files. Set a default sound or give each timer its own.

ON YOUR LOCK SCREEN
A Live Activity counts down the current interval on the Lock Screen and in the Dynamic Island, and shows up in the Smart Stack on a paired Apple Watch. Notifications mark each interval, and iOS can mirror them to your Apple Watch while your iPhone is locked.

LOG WHAT YOU DID
Finished runs are saved automatically. Add a note about what it was for and pick a category: Workout, Focus & Work, Chores, Mindfulness, Learning or Other. Forgot the timer? Log a session by hand.

SEE YOUR PROGRESS
The Today card shows your time against a daily goal, your current streak and the last seven days. The monthly overview adds a calendar shaded by time, your totals and best streak, minutes per day, where your time went and your most-used timers.

PRIVATE BY DESIGN
Your timers and log stay on your device. There's no account, no ads and no tracking.

Made for iPhone and iPad.
```

---

## 3. App Privacy, age rating and compliance answers

**App Privacy** (App Store Connect > App Privacy)
- "Do you or your third-party partners collect data from this app?" **No, we do not collect data from this app.**
- Result shown on the store: **Data Not Collected**.

**Age rating questionnaire**: every answer is None or No, which gives **4+**. The app has no violence, gambling, mature content, web browsing, chat, ads, or content shared between users. It also gives no medical guidance or self-care recommendations: it times what people set up, and its workout and meditation templates are only preset timers.

**Regulated medical device** (App Information, required for the Health & Fitness category): **No.** The app doesn't diagnose, prevent, monitor or treat anything.

**Export compliance**: `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist, so App Store Connect won't ask.

**Content rights**: "Does your app contain, show, or access third-party content?" **No.** All built-in sounds are synthesized by the app. Files people import are their own and stay on their device.

**Advertising identifier (IDFA)**: **No.**

**Accessibility Nutrition Labels**: only claim a feature after trying the app's common tasks with it on. VoiceOver labels and system text sizes were worked on, but neither has been tested end to end. It's fine to leave these blank at first.

---

## 4. Screenshots

These are made for you, using fictional sample data. Go to Actions > App Store screenshots > Run workflow, then download the `screenshots` artifact from the finished run.

| Folder | Pixels | App Store Connect slot |
| --- | --- | --- |
| `iphone-6.3-inch` | 1206 x 2622 | iPhone with Dynamic Island (medium display). **Required** |
| `iphone-6.9-inch` | 1320 x 2868 | iPhone with Dynamic Island (large display). Optional, looks sharper on big phones |
| `ipad-13-inch` | 2064 x 2752 | iPad 13-inch. **Required**, because the app runs on iPad |

Upload in filename order: timers, running, overview, log, finished, editor. `7-settings` is there for checking the app and doesn't need uploading.

A real photo of the Lock Screen Live Activity would make a strong extra one, since Simulators can't capture it. Press top button + volume up during a run, and upload it at whatever size App Store Connect accepts. Don't show anything personal in it.

---

## 5. App Review information (paste into "Notes")

Sign-in required: **No** (App Store Connect ticks this by default, so untick it). Contact: your name, phone and intervaltimersupport@gmail.com.

**Attach a screen recording** in the App Review attachment field. About 30 seconds with sound: start "Sprint 20/10", lock the iPhone, and let the beeps be heard on the Lock Screen. Developers of apps like this one report that a recording helped clear 2.5.4 questions.

```
Intervals is an interval timer with a personal log. No account or sign-in. All data stays on the device and there is no server.

BACKGROUND AUDIO (UIBackgroundModes: audio)
The main feature of the app is audible cues while the iPhone is locked: 3-2-1 countdown beeps and a sound at the start of each interval. To hear it:
1. Open the Timers tab and press the green play button on "Sprint 20/10" (intervals of 20 and 10 seconds).
2. Lock the device. Countdown beeps and interval sounds keep playing, about every 10 to 20 seconds. Please make sure the volume is up.

The audio session stays active between cues during a run so that cues play on time while locked, and this also lets the app keep the Live Activity on the current interval. The session is active only during a run: it ends when the user pauses or the run finishes. If the user turns off Settings > Audio cues, the app doesn't use background audio at all; notifications still arrive, and the Live Activity shows a prompt to open the app once it falls behind. Sound can also be previewed in Settings > Default sound.

OTHER FEATURES
- Notifications are local and optional. Permission is requested the first time a timer starts. Without it, the timer still works and a dismissible note explains what's missing.
- Live Activity: appears on the Lock Screen and Dynamic Island during a run.
- Log and Overview tabs: finish a run, or use + on the Log tab to add a session by hand. They are empty on a new install.
- Custom sounds: Settings > Default sound > Import Audio File uses the system file picker. Files are copied into the app and never leave the device.
- Privacy policy and support links: Settings > About.
- There is no companion Apple Watch app. The Watch receives mirrored notifications and the Live Activity from iOS.
```

---

## 6. TestFlight checklist

Run these on a real device. A Simulator can't confirm any of the audio or Lock Screen behavior.

- [ ] First timer start asks for notifications before the countdown begins. Try both Allow and Don't Allow (delete the app between tries).
- [ ] With Don't Allow, the note on the Timers tab appears and Not Now removes it.
- [ ] Start "Sprint 20/10" and lock the phone: beeps continue, the Live Activity moves through intervals.
- [ ] Play music in another app: the cues mix over it and don't pause it.
- [ ] Pause during a run, then lock the phone: silence, and nothing resumes by itself.
- [ ] Settings > Audio cues off, run a timer locked: notifications arrive, no sound from the app, and the Live Activity eventually says "Open Intervals to sync".
- [ ] Take a phone call during a run: cues come back after it ends.
- [ ] Finish a run, add a note: it shows in Log and Overview.
- [ ] Force-quit during a run, then reopen: the run picks up at the right place.
- [ ] Import an MP3, select it, delete it: the timer falls back to the default sound.
- [ ] Delete every interval in a timer: its play button is disabled.
- [ ] Settings > Privacy Policy and Help & Support open the right pages.
- [ ] Repeat the main screens on iPad, in portrait and landscape.
- [ ] Try the largest text size and dark mode on the main screens.

---

## 7. Guideline checklist (built into the app)

| Guideline | Requirement | How Intervals meets it |
| --- | --- | --- |
| 1.5 Developer info | A way to contact you | Settings > Help & Support; Support URL with email |
| 2.1 Completeness | Final, tested build | Sample timers on first launch; test via TestFlight before submitting |
| 2.3 Metadata | Accurate, with real screenshots | Screenshots are captured from the app itself; sample data is fictional; the description claims only mirrored notifications and the Smart Stack on Apple Watch, and the review notes say there's no Watch app |
| 2.3.7 Names and keywords | Unique name, no trademarked terms | No exact match in a public App Store search (App Store Connect has the final say); "Tabata" and "Pomodoro" removed from the app and keywords |
| 2.4.1 iPad | Run on iPad | Universal app with all iPad orientations |
| 2.5.4 Background services | Used only for intended purposes | Audio mode only runs during a run with audible cues on; off when paused, finished, or cues disabled; explained in the review notes |
| 4.2 Minimum functionality | More than a website | Native timer, Live Activity, notifications, log, charts |
| 4.5.4 / 5.1.1(iv) Notifications | Not required; respect the choice | Requested on first timer start; timers work without them; the note about them can be dismissed |
| 5.1.1(i) Privacy policy | In App Store Connect and in the app | Settings > About > Privacy Policy, and the web page |
| 5.1.1(v) Deletion | Let people delete data | No accounts. Sessions, timers and sounds can each be deleted; deleting the app removes everything |
| Required-reason APIs | Declared in a privacy manifest | `PrivacyInfo.xcprivacy` declares UserDefaults (CA92.1); no tracking or collected data |
| SDK minimum | Xcode 26 or later | Built on the newest Xcode on the GitHub Actions Mac |
| App icon | Asset catalog, 1024 px, no transparency | `Resources/Assets.xcassets/AppIcon.appiconset` (RGB, no alpha) |
| Build | Signed for distribution, built with Xcode | `.github/workflows/ios.yml`, which also checks the bundle contents on every pull request |

## 8. Later versions

Change `MARKETING_VERSION` in `project.yml` for a new version number, then run the iOS workflow again. Build numbers take care of themselves. The support address lives only on the website, so it can change without an app update.
