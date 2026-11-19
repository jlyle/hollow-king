# Android build guide (Fedora, command line)

Goal: get **Depths of the Hollow King** onto your phone, then build the signed file for Google Play.
Covers B-09, D-12, D-13, C-01, C-02, C-09, C-10. One-time setup is steps 1–6; after that it's one command.

| Command | What it does |
|---|---|
| `tools/android.sh check` | Checks everything below and tells you what's missing |
| `tools/android.sh debug` | Builds `builds/hollow-king-debug.apk` and installs it on a USB-connected phone |
| `tools/android.sh keystore` | Creates your Google Play upload key (once) |
| `tools/android.sh release` | Builds the signed `builds/hollow-king.aab` for Google Play |

If Godot is a Flatpak, prefix commands with `GODOT="flatpak run org.godotengine.Godot"`.

---

## 1. Godot
You already have it. Confirm: `godot --version` → `4.5…` or newer.

## 2. Java 17 (exactly 17)
Try the Fedora package first:
```bash
sudo dnf install java-17-openjdk-devel
```
If dnf says "No match" (newer Fedora releases moved older JDKs to Adoptium Temurin):
```bash
sudo dnf install adoptium-temurin-java-repository
sudo dnf config-manager setopt adoptium-temurin-java-repository.enabled=1
sudo dnf install temurin-17-jdk
```
Find the install folder with `ls /usr/lib/jvm/` and add it to `~/.bashrc`:
```bash
export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk      # or /usr/lib/jvm/java-17-openjdk
```

## 3. Android SDK (command-line tools, no Android Studio needed)
Don't use the SDK from Fedora's repos — Godot's docs warn it's usually outdated.

1. Download **"Command line tools only" → Linux** from https://developer.android.com/studio (bottom of the page).
2. Unpack it into the layout the tools expect:
```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
unzip ~/Downloads/commandlinetools-linux-*_latest.zip
mv cmdline-tools latest
```
3. Add to `~/.bashrc`, then open a new terminal:
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
```
4. Install the packages Godot 4.5 needs (plus API 36, which Google Play requires — C-01):
```bash
sdkmanager --licenses
sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35" "platforms;android-36" \
           "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```
If you're on a newer Godot than 4.5, check its "Exporting for Android" docs page for updated version numbers.

## 4. Godot export templates
Easiest: `godot -e --path ~/hollow-king`, then **Editor → Manage Export Templates → Download and Install**.

## 5. Point Godot at Java and the SDK (once)
In the editor: **Editor → Editor Settings → Export → Android**
- **Java SDK Path**: your `JAVA_HOME` folder from step 2
- **Android SDK Path**: `~/Android/Sdk` (type the full path, e.g. `/home/jim/Android/Sdk`)

Close the editor. Command-line builds read these settings.

## 6. Phone: enable USB debugging
1. Phone **Settings → About phone** → tap **Build number** 7 times (unlocks Developer options).
2. **Settings → System → Developer options** → turn on **USB debugging**.
3. Plug into the PC, run `adb devices`, and tap **Allow** on the phone.

Now run:
```bash
cd ~/hollow-king
tools/android.sh check
```
Fix anything marked **FIX**, then run it again until it says **All set**.

---

## 7. Play on your phone (debug build)
```bash
tools/android.sh debug
```
Builds the APK, installs it and launches the game. Watch live errors with `adb logcat -s godot`.
No cable? Copy `builds/hollow-king-debug.apk` to the phone and open it (allow "install unknown apps").

Then work through `testing.html`, section 10.

---

## 8. Google Play build (release)

**Before the first upload, confirm the package name.** It's `com.jlyle.hollowking` (D-12) and it can never change once uploaded. To change it, edit `package/unique_name` in both presets in `export_presets.cfg`.

1. Create your upload key (once), then **back it up** with the password (C-10):
   ```bash
   tools/android.sh keystore
   ```
2. Build the signed bundle:
   ```bash
   tools/android.sh release
   ```
   The first run also installs Godot's Android build template into `android/` (ignored by git).
3. **Every later upload:** raise `version/code` (1 → 2 → 3…) in the **Android Release (AAB)** preset first. Play rejects a repeated version code.

## 9. Play Console (the 14-day clock)
1. Create a developer account at https://play.google.com/console (one-time registration fee).
2. **Create app** → name "Depths of the Hollow King", Game, Free.
3. Turn on **Play App Signing** when asked. Google holds the final signing key; your keystore is only the *upload* key.
4. **Testing → Closed testing** → create a track → upload `builds/hollow-king.aab` → add testers (email list or Google Group).
5. New personal accounts need **12 testers opted in for 14 continuous days** before you can apply for production (C-03). Recruit 15–20 to allow for drop-outs, and ask them to actually play.
6. While that runs: store listing (512 px icon = `art/icon_512.png`, 1024×500 feature graphic, screenshots), privacy policy URL, content rating, Data safety form (C-07), and the SRD attribution in the description (C-04).
