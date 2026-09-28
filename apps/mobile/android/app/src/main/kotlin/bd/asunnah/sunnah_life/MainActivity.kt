package bd.asunnah.sunnah_life

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Sunnah Life platform surface:
 *  · "sunnahlife/prayer" — exact alarms (AlarmManager.setExactAndAllowWhileIdle +
 *    canScheduleExactAlarms + permission intent) and DND auto-silent
 *    (NotificationManager.setInterruptionFilter).
 *  · "sunnahlife/widget" — home-widget text updates (RemoteViews).
 *  · "sunnahlife/system" — native share sheet (ACTION_SEND), zero plugins.
 */
/** Shared by MainActivity (channel plumbing) and PrayerAlarmReceiver (posting). */
private const val NOTIFICATION_CHANNEL_ID = "sunnah_life_prayers"

class MainActivity : FlutterActivity() {
    companion object {
        private const val PRAYER_CHANNEL = "sunnahlife/prayer"
        private const val WIDGET_CHANNEL = "sunnahlife/widget"
        private const val SYSTEM_CHANNEL = "sunnahlife/system"
        private const val ALARM_ACTION = "bd.asunnah.sunnah_life.ALARM_PRAYER"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRAYER_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scheduleExactAlarm" -> {
                            val id = call.argument<Int>("id") ?: 0
                            val epochMillis = call.argument<Long>("epochMillis") ?: 0L
                            val title = call.argument<String>("title") ?: ""
                            val body = call.argument<String>("body") ?: ""
                            result.success(scheduleExactAlarm(id, epochMillis, title, body))
                        }
                        "cancelExactAlarm" -> {
                            val id = call.argument<Int>("id") ?: 0
                            cancelExactAlarm(id)
                            result.success(true)
                        }
                        "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                        "requestExactAlarmPermission" -> result.success(requestExactAlarmPermission())
                        "isDndGranted" -> result.success(isDndGranted())
                        "requestDndAccess" -> result.success(requestDndAccess())
                        "setAutoSilent" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            result.success(setAutoSilent(enabled))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("PRAYER_CHANNEL_ERROR", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateNextPrayer" -> {
                        val prayerName = call.argument<String>("prayerName") ?: ""
                        val countdown = call.argument<String>("countdown") ?: ""
                        PrayerWidgetProvider.pushUpdate(applicationContext, prayerName, countdown)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra(Intent.EXTRA_TITLE, "সুন্নাহ লাইফ")
                        }
                        startActivity(Intent.createChooser(intent, "শেয়ার করুন"))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Exact alarms ─────────────────────────────────────────────────────────

    private fun alarmManager(): AlarmManager =
        getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun canScheduleExactAlarms(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager().canScheduleExactAlarms()
        } else {
            true
        }

    /** Opens the system screen; true when an intent was actually fired. */
    fun requestExactAlarmPermission(): Boolean {
        if (canScheduleExactAlarms()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
            return true
        }
        return false
    }

    fun scheduleExactAlarm(id: Int, epochMillis: Long, title: String, body: String): Boolean {
        if (!canScheduleExactAlarms()) return false
        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
            action = ALARM_ACTION
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
        }
        val pending = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = alarmManager()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pending)
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pending)
        }
        return true
    }

    fun cancelExactAlarm(id: Int) {
        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply { action = ALARM_ACTION }
        val pending = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager().cancel(pending)
    }

    // ── DND auto-silent ───────────────────────────────────────────────────────

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun isDndGranted(): Boolean = notificationManager().isNotificationPolicyAccessGranted

    /** Opens the DND-access settings; true when an intent was actually fired. */
    fun requestDndAccess(): Boolean {
        if (isDndGranted()) return false
        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        return true
    }

    /** Priority-only during prayer windows; false when access is missing. */
    fun setAutoSilent(enabled: Boolean): Boolean {
        if (!isDndGranted()) return false
        val filter = if (enabled) {
            NotificationManager.INTERRUPTION_FILTER_PRIORITY
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
        return try {
            notificationManager().setInterruptionFilter(filter)
            true
        } catch (e: SecurityException) {
            false
        }
    }
}

/** Fires the waqt notification when the exact alarm lands. */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: return
        val body = intent.getStringExtra("body") ?: ""
        val id = intent.getIntExtra("id", 0)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(NOTIFICATION_CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "নামাজের সময়",
                    NotificationManager.IMPORTANCE_HIGH
                )
            )
        }

        val postOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        if (!postOk) return

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            // Monochrome status-bar icon (colored applicationInfo.icon renders
            // as a white square); mirrors the FCM meta-data + Dart plugin init.
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .build()
        nm.notify(id, notification)
    }
}
