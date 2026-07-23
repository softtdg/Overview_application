package com.example.overview_app

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Prevent Autofill / Password Manager from breaking password fields.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill =
                View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(AutofillManager::class.java)?.cancel()
        }
    }
}
