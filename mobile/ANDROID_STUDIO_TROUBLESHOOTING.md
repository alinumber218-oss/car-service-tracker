# Android Studio Setup — Troubleshooting

## About the errors you saw

```
Unresolved class 'MainApplication'
Unresolved class 'MainActivity'
Attribute android:icon is not allowed here
Attribute android:roundIcon is not allowed here
Attribute android:allowBackup is not allowed here
...
Cannot resolve symbol 'android:editTextBackground'
```

**None of these mean the project files are broken.** `MainActivity.kt`,
`MainApplication.kt`, and both `AndroidManifest.xml` files are byte-for-byte
the same as the official React Native 0.75.4 template (verified again while
writing this doc).

This exact error pattern — real manifest attributes like `android:icon` and
`android:allowBackup` suddenly being flagged as "not allowed" on the
`<application>` tag — is what Android Studio shows when **Gradle sync never
fully completed**. Without a successful sync, the editor has no Android
Gradle Plugin model to validate against, so it falls back to a bare/partial
XML schema that doesn't recognize the tag correctly. `Unresolved class
'MainActivity'` is the same root cause — the Kotlin compiler classpath isn't
wired up yet either.

The `'build/' pattern is defined more than once` warning was a real (but
harmless) cosmetic bug in `.gitignore` — already fixed.

## Fix, in order of likelihood

### 1. `npm install` wasn't run in `mobile/` before opening `mobile/android`

This is the most common cause. `android/settings.gradle` does:
```gradle
pluginManagement { includeBuild("../node_modules/@react-native/gradle-plugin") }
```
If `mobile/node_modules` doesn't exist yet, that `includeBuild` fails, Gradle
sync fails, and you get exactly this cascade.

**Fix:**
```bash
cd mobile
npm install
```
Then in Android Studio: click the **"Sync Now"** banner, or
**File → Sync Project with Gradle Files**.

### 2. Check the actual sync error in the Build/Event Log

Open the **Build** tab (bottom of Android Studio) or **View → Tool Windows →
Event Log** and look for the first real error — everything after it is
usually just noise. Common ones:

- **"SDK location not found"** — `android/local.properties` wasn't created.
  Create it manually with:
  ```
  sdk.dir=C:\\Users\\<you>\\AppData\\Local\\Android\\Sdk
  ```
  (Windows) or let Android Studio create it on first successful sync — it's
  already gitignored, so this is safe to do locally.
- **Wrong Gradle JDK** — Gradle 8.8 needs JDK 17. In Android Studio:
  **File → Settings → Build, Execution, Deployment → Build Tools → Gradle**,
  set **Gradle JDK** to the bundled `jbr-17` (or any JDK 17).
- **`node` not found** — the RN Gradle plugin shells out to Node during
  sync. Make sure Node.js is installed and on `PATH`, then **fully restart**
  Android Studio (Windows GUI apps only pick up `PATH` changes made before
  they were launched — reopening the project isn't enough).

### 3. Still stuck? Invalidate caches

**File → Invalidate Caches / Restart → Invalidate and Restart.**

### 4. Re-sync and confirm

After a successful sync, `MainActivity`/`MainApplication` should resolve
immediately and every manifest/styles error should disappear — they're not
independent problems, they're all downstream of the same failed sync.
