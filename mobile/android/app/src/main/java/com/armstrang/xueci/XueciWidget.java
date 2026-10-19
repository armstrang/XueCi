package com.armstrang.xueci;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONObject;

/**
 * Home-screen widget (v1.17): the learner's realm in hanzi with its pinyin and meaning, the stage and its progress,
 * today's plan in one line and the cultivation days. The page sends ready-made, localised text through
 * MMAndroid.setWidget(json) whenever Home is drawn and something changed; it is kept in SharedPreferences "widget"
 * so the widget can draw itself while the app is closed. A tap opens the app. Nothing leaves the phone.
 */
public class XueciWidget extends AppWidgetProvider {
    private static final String PREFS = "widget";

    static void save(Context c, String json) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("data", json).apply();
        update(c);
    }

    static void update(Context c) {
        AppWidgetManager m = AppWidgetManager.getInstance(c);
        int[] ids = m.getAppWidgetIds(new ComponentName(c, XueciWidget.class));
        if (ids != null && ids.length > 0) m.updateAppWidget(ids, views(c));
    }

    @Override
    public void onUpdate(Context c, AppWidgetManager m, int[] ids) {
        m.updateAppWidget(ids, views(c));
    }

    private static RemoteViews views(Context c) {
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.widget_xueci);
        Intent open = new Intent(c, MainActivity.class).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        v.setOnClickPendingIntent(R.id.w_root,
                PendingIntent.getActivity(c, 11, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        JSONObject o = null;
        try {
            String s = p.getString("data", null);
            if (s != null) o = new JSONObject(s);
        } catch (Exception ignored) {
        }
        if (o == null) {
            /* added before the app was ever opened: a quiet invitation */
            v.setTextViewText(R.id.w_realm, "学词");
            v.setTextViewText(R.id.w_py, "xuécí");
            v.setTextViewText(R.id.w_mean, c.getString(R.string.app_name));
            v.setTextViewText(R.id.w_stage, c.getString(R.string.widget_empty));
            v.setViewVisibility(R.id.w_prog, View.GONE);
            v.setViewVisibility(R.id.w_today, View.GONE);
            v.setViewVisibility(R.id.w_days, View.GONE);
            return v;
        }
        v.setTextViewText(R.id.w_realm, o.optString("r", "凡人"));
        v.setTextViewText(R.id.w_py, o.optString("py", ""));
        v.setTextViewText(R.id.w_mean, o.optString("m", ""));
        v.setTextViewText(R.id.w_stage, o.optString("s", ""));
        int pct = Math.max(0, Math.min(100, o.optInt("p", 0)));
        v.setViewVisibility(R.id.w_prog, View.VISIBLE);
        v.setProgressBar(R.id.w_prog, 100, pct, false);
        String t = o.optString("t", "");
        String tl = o.optString("tl", "");
        v.setViewVisibility(R.id.w_today, t.isEmpty() ? View.GONE : View.VISIBLE);
        v.setTextViewText(R.id.w_today, tl.isEmpty() ? t : tl + " · " + t);
        v.setViewVisibility(R.id.w_days, View.VISIBLE);
        v.setTextViewText(R.id.w_days, (o.optBoolean("lit", false) ? "香 ✓ " : "香 ") + o.optString("d", ""));
        return v;
    }
}
