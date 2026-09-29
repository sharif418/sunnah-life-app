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
 *    canScheduleExactAlarms + permission intent), DND auto-silent
 *    (NotificationManager.setInterruptionFilter) and the jama'at auto-silent
 *    window alarms (AutoSilentReceiver).
 *  · "sunnahlife/widget" — home-widget text updates (RemoteViews).
 *  · "sunnahlife/system" — native share sheet (ACTION_SEND), zero plugins.
 */
/** Shared by MainActivity (channel plumbing) and PrayerAlarmReceiver (posting). */
private const val NOTIFICATION_CHANNEL_ID = "sunnah_life_prayers"

/** Intent action of every auto-silent ringer alarm (C-W3e). */
private const val AUTO_SILENT_ACTION = "bd.asunnah.sunnah_life.AUTO_SILENT"

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
                        // C-W3e — arm one ringer edge of a jama'at silent
                        // window (id = deterministic request code owned by
                        // the Dart Nid scheme; on = silence or restore).
                        "scheduleAutoSilent" -> {
                            val id = call.argument<Int>("id") ?: 0
                            val epochMillis = call.argument<Long>("epochMillis") ?: 0L
                            val on = call.argument<Boolean>("on") ?: false
                            result.success(scheduleAutoSilent(id, epochMillis, on))
                        }
                        "cancelAutoSilent" -> {
                            val ids = call.argument<List<Int>>("ids") ?: emptyList()
                            cancelAutoSilent(ids)
                            result.success(true)
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
                        WidgetRender.pushLive(applicationContext, prayerName, countdown)
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

    // ── DND auto-silent (C-W3e) ───────────────────────────────────────────────

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun isDndGranted(): Boolean = AutoSilent.isGranted(this)

    /** Opens the DND-access settings; true when an intent was actually fired. */
    fun requestDndAccess(): Boolean {
        if (isDndGranted()) return false
        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        return true
    }

    /** Priority-only during prayer windows; false when access is missing. */
    fun setAutoSilent(enabled: Boolean): Boolean = AutoSilent.apply(this, enabled)

    /**
     * Arm one auto-silent ringer edge: at [epochMillis] the
     * [AutoSilentReceiver] flips the ringer to priority-only ([on]) or
     * restores it. Exact when the OS granted SCHEDULE_EXACT_ALARM (same
     * guarded fallback as the W3b bells — a slightly-late ringer change
     * beats nothing), inexact setAndAllowWhileIdle otherwise.
     */
    fun scheduleAutoSilent(id: Int, epochMillis: Long, on: Boolean): Boolean {
        val intent = Intent(this, AutoSilentReceiver::class.java).apply {
            action = AUTO_SILENT_ACTION
            putExtra("id", id)
            putExtra("on", on)
        }
        val pending = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = alarmManager()
        if (canScheduleExactAlarms()) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pending)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pending)
        }
        return true
    }

    /** Cancel the armed auto-silent alarms by their Dart-owned ids. */
    fun cancelAutoSilent(ids: List<Int>) {
        val am = alarmManager()
        for (id in ids) {
            val intent = Intent(this, AutoSilentReceiver::class.java).apply {
                action = AUTO_SILENT_ACTION
            }
            val pending = PendingIntent.getBroadcast(
                this,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pending)
        }
    }
}

/**
 * Shared DND auto-silent logic — used by BOTH the MainActivity channel
 * handler (manual toggle / restore-on-disable) and the [AutoSilentReceiver]
 * (alarm fires while the app is dead). The receiver must never depend on
 * the Flutter engine being alive.
 *
 * Safety: the restore only clears a silence WE started (the
 * `autosilent_engaged` marker in the app's default SharedPreferences), so a
 * window ending never switches off a DND mode the user turned on
 * themselves; a permission loss degrades to a no-op instead of a crash.
 */
object AutoSilent {
    private const val ENGAGED_PREF = "autosilent_engaged"

    private fun prefs(context: Context) =
        context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)

    fun isGranted(context: Context): Boolean =
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .isNotificationPolicyAccessGranted

    fun apply(context: Context, enabled: Boolean): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!nm.isNotificationPolicyAccessGranted) return false
        val prefs = prefs(context)
        return try {
            if (enabled) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                prefs.edit().putBoolean(ENGAGED_PREF, true).apply()
            } else if (prefs.getBoolean(ENGAGED_PREF, false)) {
                // Only restore a silence this app set — never clobber the
                // user's own DND.
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                prefs.edit().putBoolean(ENGAGED_PREF, false).apply()
            }
            true
        } catch (e: SecurityException) {
            false
        }
    }
}

/**
 * Fires the DND flip at a jama'at window edge (C-W3e). Armed by
 * MainActivity.scheduleAutoSilent; runs without the Flutter engine, so the
 * ringer flips even when the app was never opened that day. Honest edge:
 * Android clears alarms on reboot — the Dart refresh (app open / resume /
 * day rollover) re-arms them; there is deliberately no boot receiver here
 * because the permission probe + settings state live behind the Dart
 * scheduler.
 */
class AutoSilentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val on = intent.getBooleanExtra("on", false)
        AutoSilent.apply(context, on)
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
