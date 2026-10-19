package com.armstrang.xueci

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Daily study reminder. The app chooses the time and the text (in the study language); this keeps them in
 * SharedPreferences "reminder", sets one inexact alarm for the next reminder time and shows the notification when it
 * fires, unless the learner already practised that day (markStudied) or it is one of their meditation days
 * (setRestDays). Nothing leaves the phone.
 */
object Reminder {
    const val ACTION = "com.armstrang.xueci.REMIND"
    private const val PREFS = "reminder"
    private const val CHANNEL = "study"
    private const val NOTIFICATION_ID = 7

    private fun prefs(c: Context): SharedPreferences = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Saves the settings from the app and sets (or cancels) the alarm. */
    fun save(c: Context, on: Boolean, hour: Int, minute: Int, title: String, text: String, channel: String) {
        prefs(c).edit()
            .putBoolean("on", on)
            .putInt("hour", hour.coerceIn(0, 23))
            .putInt("minute", minute.coerceIn(0, 59))
            .putString("title", title)
            .putString("text", text)
            .putString("channel", channel)
            .apply()
        if (on) schedule(c) else cancel(c)
    }

    /** The learner practised today: no reminder today, and one already showing goes away. */
    fun markStudied(c: Context) {
        prefs(c).edit().putString("studied", today()).apply()
        NotificationManagerCompat.from(c).cancel(NOTIFICATION_ID)
    }

    /** Rest weekdays as "0,3" (0 = Sunday … 6 = Saturday); empty = none. */
    fun setRestDays(c: Context, days: String?) {
        val clean = (days ?: "").split(',').map { it.trim() }
            .filter { it.length == 1 && it[0] in '0'..'6' }
            .distinct()
            .joinToString(",")
        prefs(c).edit().putString("rest", clean).apply()
    }

    private fun restToday(p: SharedPreferences): Boolean {
        val rest = p.getString("rest", "") ?: ""
        if (rest.isEmpty()) return false
        val today = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) - 1).toString() // Calendar: Sunday = 1
        return rest.split(',').any { it == today }
    }

    private fun alarmIntent(c: Context): PendingIntent {
        val i = Intent(c, ReminderReceiver::class.java).setAction(ACTION)
        return PendingIntent.getBroadcast(c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** One inexact alarm at the next reminder time (no exact-alarm permission needed; a few minutes late is fine). */
    fun schedule(c: Context) {
        val p = prefs(c)
        if (!p.getBoolean("on", false)) return
        val at = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt("hour", 19))
            set(Calendar.MINUTE, p.getInt("minute", 0))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (at.timeInMillis <= System.currentTimeMillis() + 30_000) at.add(Calendar.DAY_OF_YEAR, 1)
        val am = c.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.timeInMillis, alarmIntent(c))
    }

    fun cancel(c: Context) {
        (c.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.cancel(alarmIntent(c))
        NotificationManagerCompat.from(c).cancel(NOTIFICATION_ID)
    }

    /** Called when the alarm fires. */
    fun show(c: Context) {
        val p = prefs(c)
        if (!p.getBoolean("on", false) || today() == p.getString("studied", "") || restToday(p)) return
        val nm = NotificationManagerCompat.from(c)
        if (!nm.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL, p.getString("channel", "Study reminder"), NotificationManager.IMPORTANCE_DEFAULT)
            c.getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
        }
        val open = Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(c, 1, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val text = p.getString("text", "") ?: ""
        val b = NotificationCompat.Builder(c, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_xueci)
            .setColor(0xFF2F8A4C.toInt())
            .setContentTitle(p.getString("title", "XueCi Mandarin"))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(tap)
            .setAutoCancel(true)
        try {
            nm.notify(NOTIFICATION_ID, b.build())
        } catch (_: SecurityException) {
            // the notification permission was taken away: nothing to show
        }
    }
}

/**
 * The reminder alarm fires here: show today's reminder (if still needed) and set the next one. After a restart, an
 * app update or a clock/time-zone change the alarm is set again, because Android forgets alarms on reboot.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Reminder.ACTION) Reminder.show(context)
        Reminder.schedule(context)
    }
}
