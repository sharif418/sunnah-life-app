package bd.asunnah.sunnah_life

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

/**
 * Home-screen widget: next prayer + countdown (RemoteViews).
 *
 * TWO render paths share ONE view-binding ([WidgetRender.renderInto]) so they
 * can never diverge:
 *  · LIVE — the Flutter side pushes updates through the "sunnahlife/widget"
 *    MethodChannel every prayer tick (PrayerNotifier._updateWidget).
 *  · PERSISTED (C-W3f) — [WidgetRender.renderFromSnapshot] reads the JSON
 *    snapshot the Dart side persists after every tick (SharedPreferences
 *    `flutter.widget_snapshot`), so after process death, package update or
 *    reboot the widget shows real data instead of resetting to "--:--".
 *
 * The Flutter engine stays the source of truth — the Kotlin side never
 * recomputes prayer times; it only renders the snapshot (extending the
 * snapshot's day by +24h slots for up to ~2 days, the same approximation the
 * Dart writer itself makes across midnight). When the snapshot is missing or
 * older than that, the widget shows an honest "ওয়াক্ত পার হয়েছে" stale
 * marker + the city — never a silently blank tile. Opening the app
 * re-freshes the snapshot immediately.
 */
class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetRender.renderFromSnapshot(context)
        WidgetRender.schedulePeriodicRerender(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // The periodic re-render alarm + boot restore fire ACTION_RENDER.
        if (intent.action == WidgetRender.ACTION_RENDER) {
            WidgetRender.renderFromSnapshot(context)
        }
    }
}

/**
 * Renders the widget after a reboot / package update (C-W3f): the snapshot
 * survives both (it lives in SharedPreferences), so the widget comes back
 * with real data + the periodic re-render alarm is re-armed.
 * RECEIVE_BOOT_COMPLETED + the manifest entry make this work while the
 * Flutter engine is completely dead.
 */
class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetRender.renderFromSnapshot(context)
        WidgetRender.schedulePeriodicRerender(context)
    }
}

/** All widget rendering — one place, used by every path above. */
object WidgetRender {
    /** Matches PrayerWidgetProvider's manifest-declared custom action. */
    const val ACTION_RENDER = "bd.asunnah.sunnah_life.WIDGET_RENDER"

    /**
     * Flutter's shared_preferences writes the app's DEFAULT prefs file
     * (`<package>_preferences`) with a `flutter.` key prefix.
     */
    private const val SNAPSHOT_KEY = "flutter.widget_snapshot"

    /** Periodic re-render cadence (inexact — see [schedulePeriodicRerender]). */
    private const val RERENDER_INTERVAL_MS = 15L * 60 * 1000

    /** Bengali waqt labels (mirror of the Dart prayerLabelsBn). */
    private val LABELS_BN = mapOf(
        "fajr" to "ফজর",
        "dhuhr" to "যোহর",
        "asr" to "আসর",
        "maghrib" to "মাগরিব",
        "isha" to "এশা"
    )

    private val BN_DIGITS = arrayOf("০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯")

    private fun toBn(value: Int): String =
        value.toString().map { c -> if (c in '0'..'9') BN_DIGITS[c - '0'] else c }.joinToString("")

    /** What the two text rows of the widget should show. */
    data class Content(
        val prayerName: String,
        val countdown: String,
        /** Stale snapshot — the honest marker replaces the countdown. */
        val stale: Boolean = false
    )

    // ── Shared view binding ───────────────────────────────────────────────────

    /** Bind [content] into [views] — the ONE place the rows are filled. */
    fun renderInto(views: RemoteViews, content: Content) {
        if (content.stale) {
            views.setTextViewText(R.id.widget_prayer_name, "ওয়াক্ত পার হয়েছে")
            // City (or the app name as the last-resort label) — never blank.
            views.setTextViewText(R.id.widget_countdown, content.countdown)
        } else {
            views.setTextViewText(R.id.widget_prayer_name, content.prayerName)
            views.setTextViewText(R.id.widget_countdown, content.countdown)
        }
    }

    private fun baseViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, open)
        return views
    }

    private fun push(context: Context, content: Content) {
        val views = baseViews(context)
        renderInto(views, content)
        AppWidgetManager.getInstance(context).updateAppWidget(
            ComponentName(context, PrayerWidgetProvider::class.java),
            views
        )
    }

    // ── LIVE path (Flutter engine ticking) ────────────────────────────────────

    /** Called from MainActivity when the countdown ticks. */
    fun pushLive(context: Context, prayerName: String, countdown: String) {
        push(context, Content(prayerName, countdown))
    }

    // ── PERSISTED path (engine dead / rebooted) ───────────────────────────────

    /**
     * Read the persisted snapshot and render it. Shapes (written by the Dart
     * WidgetSnapshotService after every prayer tick):
     *   {city, dateKey "YYYY-MM-DD", times {waqt: "HH:mm" × 10},
     *    nextKey, nextAt epoch-millis, nextLabelBn}
     *
     * Rendering rules:
     *  · nextAt in the future → its label + "H ঘ M মি" countdown (same
     *    format the live path pushes);
     *  · nextAt in the past → the next farz slot from the times map
     *    (extended over the following days with the Dart writer's own
     *    ±1–2 min/day +24h approximation, up to 2 extra days), else the
     *    stale marker + city.
     */
    fun renderFromSnapshot(context: Context) {
        val content = readSnapshotContent(context) ?: return
        push(context, content)
    }

    private fun readSnapshotContent(context: Context): Content? {
        return try {
            val prefs = context.getSharedPreferences(
                "${context.packageName}_preferences", Context.MODE_PRIVATE
            )
            val raw = prefs.getString(SNAPSHOT_KEY, null) ?: return null
            val snap = JSONObject(raw)

            val city = snap.optString("city", "")
            val nextAt = snap.optLong("nextAt", 0L)
            val nextLabelBn = snap.optString("nextLabelBn", "")
            val times = snap.optJSONObject("times") ?: return null
            val now = System.currentTimeMillis()

            if (nextAt > now && nextLabelBn.isNotEmpty()) {
                return contentFor(nextLabelBn, nextAt, now)
            }

            // nextAt already passed — the engine is dead. Try to resolve the
            // next farz from the persisted day's times (+24h per extra day,
            // the same approximation the Dart writer makes across midnight).
            val dateKey = snap.optString("dateKey", "")
            val dayStart = parseDateKey(dateKey) ?: return staleContent(city)
            for (extraDays in 0..2) {
                for (waqt in listOf("fajr", "dhuhr", "asr", "maghrib", "isha")) {
                    val hhmm = times.optString(waqt, "")
                    val at = parseHm(dayStart, hhmm, extraDays)
                    if (at != null && at > now) {
                        return contentFor(LABELS_BN[waqt] ?: waqt, at, now)
                    }
                }
            }
            staleContent(city)
        } catch (e: Exception) {
            // Malformed snapshot must never crash a widget broadcast.
            null
        }
    }

    private fun contentFor(label: String, at: Long, now: Long): Content {
        val diffMin = ((at - now) / 60000L).toInt()
        val h = diffMin / 60
        val m = diffMin % 60
        return Content(label, "${toBn(h)} ঘ ${toBn(m)} মি")
    }

    private fun staleContent(city: String): Content {
        val label = if (city.isNotEmpty()) city else "সুন্নাহ লাইফ"
        return Content("ওয়াক্ত পার হয়েছে", label, stale = true)
    }

    private fun parseDateKey(key: String): Calendar? {
        if (!Regex("^\\d{4}-\\d{2}-\\d{2}$").matches(key)) return null
        return try {
            val parts = key.split("-").map { it.toInt() }
            Calendar.getInstance().apply {
                set(parts[0], parts[1] - 1, parts[2], 0, 0, 0)
                set(Calendar.MILLISECOND, 0)
            }
        } catch (e: Exception) {
            null
        }
    }

    /** "HH:mm" on [day] (+[extraDays] days) → epoch millis; null if malformed. */
    private fun parseHm(day: Calendar, hhmm: String, extraDays: Int): Long? {
        if (!Regex("^\\d{1,2}:\\d{2}$").matches(hhmm)) return null
        return try {
            val (h, m) = hhmm.split(":").map { it.toInt() }
            val cal = day.clone() as Calendar
            cal.add(Calendar.DAY_OF_MONTH, extraDays)
            cal.set(Calendar.HOUR_OF_DAY, h)
            cal.set(Calendar.MINUTE, m)
            cal.timeInMillis
        } catch (e: Exception) {
            null
        }
    }

    // ── Periodic re-render (clock-ish refresh without the engine) ──────────────

    /**
     * Re-render from the snapshot every ~15 min while the engine is dead.
     * Inexact repeating on purpose: an exact chain would burn the
     * SCHEDULE_EXACT_ALARM budget (and still need the permission granted);
     * a countdown tile tolerates a few minutes of drift, and missed fires
     * while the device sleeps are coalesced on wake — exactly when the
     * widget becomes visible again. The live path takes over (and re-arms
     * this alarm via onUpdate) whenever the app runs.
     */
    fun schedulePeriodicRerender(context: Context) {
        val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
            action = ACTION_RENDER
        }
        val pending = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setInexactRepeating(
            AlarmManager.RTC,
            System.currentTimeMillis() + RERENDER_INTERVAL_MS,
            RERENDER_INTERVAL_MS,
            pending
        )
    }
}
