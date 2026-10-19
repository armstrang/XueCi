package com.armstrang.xueci

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home-screen widget: the learner's realm in hanzi with its pinyin and meaning, the stage and its progress, today's
 * practice in one line and the cultivation days. The app sends ready-made, localised text (App.syncWidget) whenever
 * something changed; it is kept in SharedPreferences "widget" so the widget can draw itself while the app is closed.
 * A tap opens the app. Nothing leaves the phone.
 */
class XueciWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) {
        m.updateAppWidget(ids, views(c))
    }

    companion object {
        private const val PREFS = "widget"

        fun save(c: Context, json: String) {
            c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("data", json).apply()
            update(c)
        }

        fun update(c: Context) {
            val m = AppWidgetManager.getInstance(c)
            val ids = m.getAppWidgetIds(ComponentName(c, XueciWidget::class.java))
            if (ids != null && ids.isNotEmpty()) m.updateAppWidget(ids, views(c))
        }

        private fun views(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_xueci)
            val open = Intent(c, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            v.setOnClickPendingIntent(
                R.id.w_root,
                PendingIntent.getActivity(c, 11, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )
            val o = try {
                c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("data", null)?.let { JSONObject(it) }
            } catch (_: Exception) {
                null
            }
            if (o == null) {
                // added before the app was ever opened: a quiet invitation
                v.setTextViewText(R.id.w_realm, "学词")
                v.setTextViewText(R.id.w_py, "xuécí")
                v.setTextViewText(R.id.w_mean, c.getString(R.string.app_name))
                v.setTextViewText(R.id.w_stage, c.getString(R.string.widget_empty))
                v.setViewVisibility(R.id.w_prog, View.GONE)
                v.setViewVisibility(R.id.w_today, View.GONE)
                v.setViewVisibility(R.id.w_days, View.GONE)
                return v
            }
            v.setTextViewText(R.id.w_realm, o.optString("r", "凡人"))
            v.setTextViewText(R.id.w_py, o.optString("py", ""))
            v.setTextViewText(R.id.w_mean, o.optString("m", ""))
            v.setTextViewText(R.id.w_stage, o.optString("s", ""))
            v.setViewVisibility(R.id.w_prog, View.VISIBLE)
            v.setProgressBar(R.id.w_prog, 100, o.optInt("p", 0).coerceIn(0, 100), false)
            val t = o.optString("t", "")
            val tl = o.optString("tl", "")
            v.setViewVisibility(R.id.w_today, if (t.isEmpty()) View.GONE else View.VISIBLE)
            v.setTextViewText(R.id.w_today, if (tl.isEmpty()) t else "$tl · $t")
            v.setViewVisibility(R.id.w_days, View.VISIBLE)
            v.setTextViewText(R.id.w_days, (if (o.optBoolean("lit", false)) "香 ✓ " else "香 ") + o.optString("d", ""))
            return v
        }
    }
}
