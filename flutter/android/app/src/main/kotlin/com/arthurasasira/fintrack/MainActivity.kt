package com.arthurasasira.fintrack

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation (androidx.biometric.BiometricPrompt) requires a
// FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
