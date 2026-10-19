package com.armstrang.xueci;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

/**
 * Daily study reminder. The page chooses the time and the text (in the study language) through the
 * MMAndroid bridge; this class keeps them in SharedPreferences, sets one inexact alarm for the next
 * reminder time, and shows the notification when it fires — unless the learner already practised
 * that day (the page calls markStudied() on the first answer of a day) or the day is one of the learner's
 * meditation days (闭关, a chosen rest day; the page sends them with setRestDays()). Nothing leaves the phone.
 */
final class Reminder {
    static final String ACTION = "com.armstrang.xueci.REMIND";
    private static final String PREFS = "reminder";
    private static final String CHANNEL = "study";
    private static final int NOTIFICATION_ID = 7;

    private Reminder() {
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static String today() {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
    }

    /** Saves the settings from the page and sets (or cancels) the alarm. */
    static void save(Context c, boolean on, int hour, int minute, String title, String text, String channel) {
        prefs(c).edit()
                .putBoolean("on", on)
                .putInt("hour", Math.max(0, Math.min(23, hour)))
                .putInt("minute", Math.max(0, Math.min(59, minute)))
                .putString("title", title)
                .putString("text", text)
                .putString("channel", channel)
                .apply();
        if (on) schedule(c);
        else cancel(c);
    }

    /** The learner practised today: no reminder today, and a reminder already showing goes away. */
    static void markStudied(Context c) {
        prefs(c).edit().putString("studied", today()).apply();
        NotificationManagerCompat.from(c).cancel(NOTIFICATION_ID);
    }

    /** Rest weekdays as "0,3" (0 = Sunday … 6 = Saturday, the page's numbering); empty = none. */
    static void setRestDays(Context c, String days) {
        StringBuilder clean = new StringBuilder();
        if (days != null) {
            for (String d : days.split(",")) {
                String t = d.trim();
                if (t.length() == 1 && t.charAt(0) >= '0' && t.charAt(0) <= '6' && clean.indexOf(t) < 0) {
                    if (clean.length() > 0) clean.append(',');
                    clean.append(t);
                }
            }
        }
        prefs(c).edit().putString("rest", clean.toString()).apply();
    }

    private static boolean restToday(SharedPreferences p) {
        String rest = p.getString("rest", "");
        if (rest.isEmpty()) return false;
        String today = String.valueOf(Calendar.getInstance().get(Calendar.DAY_OF_WEEK) - 1);   // Calendar: Sunday = 1
        for (String d : rest.split(",")) if (d.equals(today)) return true;
        return false;
    }

    private static PendingIntent alarmIntent(Context c) {
        Intent i = new Intent(c, ReminderReceiver.class).setAction(ACTION);
        return PendingIntent.getBroadcast(c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** One inexact alarm at the next reminder time (no exact-alarm permission needed; a few minutes late is fine). */
    static void schedule(Context c) {
        SharedPreferences p = prefs(c);
        if (!p.getBoolean("on", false)) return;
        Calendar at = Calendar.getInstance();
        at.set(Calendar.HOUR_OF_DAY, p.getInt("hour", 19));
        at.set(Calendar.MINUTE, p.getInt("minute", 0));
        at.set(Calendar.SECOND, 0);
        at.set(Calendar.MILLISECOND, 0);
        if (at.getTimeInMillis() <= System.currentTimeMillis() + 30_000) at.add(Calendar.DAY_OF_YEAR, 1);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.getTimeInMillis(), alarmIntent(c));
    }

    static void cancel(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(alarmIntent(c));
        NotificationManagerCompat.from(c).cancel(NOTIFICATION_ID);
    }

    /** Called when the alarm fires. */
    static void show(Context c) {
        SharedPreferences p = prefs(c);
        if (!p.getBoolean("on", false) || today().equals(p.getString("studied", "")) || restToday(p)) return;
        NotificationManagerCompat nm = NotificationManagerCompat.from(c);
        if (!nm.areNotificationsEnabled()) return;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, p.getString("channel", "Study reminder"), NotificationManager.IMPORTANCE_DEFAULT);
            NotificationManager sys = c.getSystemService(NotificationManager.class);
            if (sys != null) sys.createNotificationChannel(ch);
        }
        Intent open = new Intent(c, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent tap = PendingIntent.getActivity(c, 1, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        String text = p.getString("text", "");
        NotificationCompat.Builder b = new NotificationCompat.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_xueci)
                .setColor(0xFF2F8A4C)
                .setContentTitle(p.getString("title", "XueCi Mandarin"))
                .setContentText(text)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(text))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(tap)
                .setAutoCancel(true);
        try {
            nm.notify(NOTIFICATION_ID, b.build());
        } catch (SecurityException ignored) {
            // notification permission was taken away; nothing to show
        }
    }
}
