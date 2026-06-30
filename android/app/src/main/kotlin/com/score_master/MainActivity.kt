package com.score_master

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (а не FlutterActivity) — требуется для local_auth
// (биометрия через BiometricPrompt).
class MainActivity : FlutterFragmentActivity()
