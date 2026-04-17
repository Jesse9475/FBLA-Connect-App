# iOS Build Guide — FBLA Connect

## Prerequisites
- Xcode 15+ installed
- Apple Developer account (free or paid)
- Physical iOS device connected via USB or same WiFi

## Step 1: Set the Backend URL
Before building, update the Flask backend URL for your device:

```bash
cd flutter/fbla_connect_app
flutter run --dart-define=BACKEND_URL=http://<YOUR_MAC_IP>:5050/api
```

Find your Mac's IP: System Settings → Wi-Fi → Details → IP Address

## Step 2: Open in Xcode
```bash
cd ios
open Runner.xcworkspace
```

## Step 3: Configure Signing
1. Select "Runner" in the project navigator
2. Go to "Signing & Capabilities" tab
3. Check "Automatically manage signing"
4. Select your Apple Developer team
5. Xcode will create a provisioning profile automatically

## Step 4: Select Your Device
1. Connect your iPhone via USB (first time) or ensure same WiFi
2. Select your device from the device dropdown in Xcode toolbar
3. If prompted, trust the computer on your iPhone

## Step 5: Build & Run
Option A — From Xcode:
- Click the Play button (⌘R)

Option B — From Terminal:
```bash
cd flutter/fbla_connect_app
flutter run --release --dart-define=BACKEND_URL=http://<YOUR_MAC_IP>:5050/api
```

## Step 6: Trust Developer on iPhone
First time only:
1. iPhone → Settings → General → VPN & Device Management
2. Find your Apple ID under "Developer App"
3. Tap "Trust"

## Step 7: Start the Backend
On your Mac, start the Flask server:
```bash
cd /path/to/FBLA_APP_SURYA
python app.py
```
The server runs on port 5050 by default.

## Troubleshooting
- **"Untrusted Developer"**: See Step 6
- **Network errors in app**: Make sure your Mac and iPhone are on the same WiFi. Check the backend URL matches your Mac's current IP.
- **"No provisioning profile"**: Make sure you selected a valid team in Step 3
- **Build fails with signing error**: Try cleaning: Product → Clean Build Folder (⇧⌘K), then rebuild
