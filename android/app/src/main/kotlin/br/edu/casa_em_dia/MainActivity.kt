package br.edu.casa_em_dia

import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("casa", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "casa_em_dia/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readSession" -> result.success(preferences.getString("session", null))
                    "writeSession" -> {
                        preferences.edit().putString("session", call.arguments as String).apply()
                        result.success(null)
                    }
                    "syncReminders" -> {
                        val tasks = call.arguments as? List<*> ?: emptyList<Any>()
                        ReminderReceiver.sync(this, tasks.filterIsInstance<Map<*, *>>())
                        result.success(null)
                    }
                    "requestReminders" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) {
                                result.success(false)
                            } else {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4)
                            }
                        } else {
                            result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled())
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}

