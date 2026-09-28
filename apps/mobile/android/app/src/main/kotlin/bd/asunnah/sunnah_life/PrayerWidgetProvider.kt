package bd.asunnah.sunnah_life

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget: next prayer + countdown (RemoteViews). The Flutter side
 * pushes updates through the "sunnahlife/widget" MethodChannel; tapping the
 * widget opens the app.
 */
class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val views = buildViews(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        fun buildViews(context: Context): RemoteViews {
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

        /** Called from MainActivity when the countdown ticks. */
        fun pushUpdate(context: Context, prayerName: String, countdown: String) {
            val views = buildViews(context)
            views.setTextViewText(R.id.widget_prayer_name, prayerName)
            views.setTextViewText(R.id.widget_countdown, countdown)
            AppWidgetManager.getInstance(context).updateAppWidget(
                ComponentName(context, PrayerWidgetProvider::class.java),
                views
            )
        }
    }
}
