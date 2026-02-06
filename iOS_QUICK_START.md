# iOS Build & Deploy - Quick Start

## 1️⃣ Initial Setup (One Time)

### On Windows:
```powershell
# Make sure git is configured
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Clone/init your repo
cd d:\TYRE PREASSURE APP\tyre_preassure
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/tyre_preassure.git
git push -u origin main
```

---

## 2️⃣ Automatic Builds

Every time you push:
```bash
git add .
git commit -m "describe your change"
git push origin main
```

✅ GitHub Actions automatically:
- Starts a macOS build
- Compiles iOS app
- Generates `.ipa` file
- Uploads as artifact (7-day retention)

---

## 3️⃣ Download & Install

### On GitHub:
1. Go to **Actions** tab
2. Click latest **"Build iOS App"** run
3. Scroll to **Artifacts** → Download `ios-app`
4. Unzip → get `app.ipa`

### On iPhone:
- **Easiest:** Use **Altstore** (see iOS_DEPLOYMENT.md for link)
- Or: Windows tool **ios-app-signer**
- Or: Connect Mac + Xcode

---

## 4️⃣ What Gets Built?

✅ Latest Flutter code  
✅ All sensors (Bluetooth, GPS, accelerometer)  
✅ FIT file recording  
✅ Test history persistence  
✅ Quadratic regression analysis  

---

## 5️⃣ Troubleshooting Build

**Build Failed?** Check the log:
- GitHub Actions > Failed run > Logs
- Look for `Error:` messages
- Common issues:
  - Old Flutter version → edit `.github/workflows/build_ios.yml`
  - Pod dependency → run `flutter clean` then push

**Re-trigger build:**
```bash
git commit --allow-empty -m "Rebuild"
git push origin main
```

---

## 💡 Pro Tips

- Test once locally first: `flutter build ios --release --no-codesign`
- Keep `.ipa` files for 7 days (GitHub auto-deletes after)
- Altstore auth expires after 7 days (free Apple ID limit) → quick re-sign needed
- Each iPhone needs separate install (not shared via App Store)

---

## Need Help?

- 📖 Full guide: See `iOS_DEPLOYMENT.md`
- 🐛 Build fails: Check GitHub Actions logs
- 📱 Install fails: Try Altstore first (most reliable)
