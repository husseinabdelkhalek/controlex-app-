package com.example.controlex

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Update the intent so Flutter plugins (including home_widget) can read it
        setIntent(intent)
    }
}
