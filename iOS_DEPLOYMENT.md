# iOS Deployment Guide

## Automated Build with GitHub Actions

### Step 1: Push to GitHub
```bash
git add .
git commit -m "iOS build setup"
git push origin main
```

GitHub Actions will automatically start building. Check progress at:
```
https://github.com/YOUR_USERNAME/tyre_preassure/actions
```

### Step 2: Download the IPA
1. Go to the "Build iOS App" workflow run
2. Scroll to **Artifacts** section
3. Download `ios-app.zip` (contains `app.ipa`)
4. Unzip to get `app.ipa`

---

## Installing on iPhone (No Developer Account Needed)

### Option A: **Altstore** (Easiest, FREE)
1. Download [Altstore](https://altstore.io) on Mac/Windows
2. Connect iPhone via USB
3. Open Altstore → App Browser → Search "Perfect Pressure"
4. Or drag & drop `app.ipa` into Altstore
5. Enter your Apple ID (free account OK)
6. Done! ✅

**Note:** Free Apple ID apps expire after 7 days, need re-signing (takes 30 sec)

---

### Option B: **ios-app-signer** (Windows)
1. Download [ios-app-signer](https://github.com/DanTheMan827/ios-app-signer/releases)
2. Open app, select `app.ipa`
3. Click "Start" (no certificate needed for ad-hoc)
4. Connect iPhone, open Xcode
5. Go to: Window → Devices & Simulators → Select your iPhone
6. Drag signed IPA onto the app list
7. Done! ✅

---

### Option C: **Apple Configurator 2** (Mac)
1. Download from App Store (free)
2. Connect iPhone
3. Drag `app.ipa` → Apple Configurator window
4. Follow prompts to install
5. Trust certificate on iPhone when prompted

---

### Option D: **Xcode** (requires Mac)
```bash
# Build signed IPA
xcode-select --install
open ios/Runner.xcworkspace
# In Xcode: Product → Archive → Distribute → Ad Hoc
```

---

## Testing on Physical iPhone

After installation:

1. **Trust the Developer Certificate:**
   - Settings → General → VPN & Device Management
   - Tap your certificate
   - Click "Trust [Your Name]"

2. **Grant Permissions:**
   - Bluetooth
   - Location
   - Motion & Fitness

3. **Test Recording:**
   - Pair your power meter
   - Start a test run
   - Check FIT file in Files app → tyre_sessions

---

## Updating the App

Just push new code to GitHub:
```bash
git add .
git commit -m "bug fix: ..."
git push origin main
```

GitHub Actions rebuilds automatically → Download new IPA → Re-sign with Altstore

---

## Troubleshooting

**"Installation failed" on iPhone:**
- 💡 Untrust the old certificate first in Settings
- 💡 Try a different signing method (Altstore usually works best)

**App crashes on launch:**
- 💡 Check iPhone logs: Settings → Privacy → Analytics → Analytics Data
- 💡 Rebuild with latest code

**Bluetooth not connecting:**
- 💡 Toggle Bluetooth off/on
- 💡 Forget and re-pair the sensor
- 💡 Check app has Bluetooth permission

---

**Questions?** Check GitHub Actions logs or rebuild with debug info.
