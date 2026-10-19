package com.armstrang.xueci;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Base64;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;

import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.core.splashscreen.SplashScreen;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.webkit.WebViewAssetLoader;

import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Hosts the XueCi Mandarin page (assets/index.html) in a WebView.
 * The page is served from https://appassets.androidplatform.net so it gets a stable origin
 * and localStorage (study progress, theme, language) survives app restarts and updates.
 *
 * Edge-to-edge (enforced from Android 15 for apps targeting API 35+): the window draws behind the
 * status and navigation bars. Two coloured strips sized from the window insets sit where the bars
 * are, so the page never slides under them, and the page picks their colours through setBars().
 * The bottom strip also grows with the keyboard, which keeps text fields above it.
 */
public class MainActivity extends AppCompatActivity {

    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/assets/index.html";

    private WebView web;
    private LinearLayout root;
    private View topBar, bottomBar;

    // Pronunciation with the phone's own text-to-speech engine (Mandarin voice).
    private TextToSpeech tts;
    private volatile String ttsState = "init";   // init | ready | missing | unsupported | none
    private String pendingText;
    private float pendingRate = 1f;
    private int utterance;

    // Daily study reminder: Android 13+ asks the learner before an app may post notifications.
    private ActivityResultLauncher<String> notifPermission;

    // The splash (Android 12+ system splash, earlier versions the same window) stays until the page has drawn Home,
    // or 2.5 s at most, so there is never an empty screen between the icon and the app.
    private volatile boolean pageReady = false;
    private long startedAt;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        startedAt = SystemClock.uptimeMillis();
        SplashScreen splash = SplashScreen.installSplashScreen(this);
        splash.setKeepOnScreenCondition(() -> !pageReady && SystemClock.uptimeMillis() - startedAt < 2500);
        super.onCreate(savedInstanceState);

        Window window = getWindow();
        WindowCompat.setDecorFitsSystemWindows(window, false);
        if (Build.VERSION.SDK_INT < 35) {
            // Below Android 15 the bars are drawn by the system on top of the window; keep them clear.
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
        }
        if (Build.VERSION.SDK_INT >= 29) {
            window.setStatusBarContrastEnforced(false);
            window.setNavigationBarContrastEnforced(false);
        }

        int bg = ContextCompat.getColor(this, R.color.mm_bg);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(bg);
        topBar = new View(this);
        topBar.setBackgroundColor(bg);
        bottomBar = new View(this);
        bottomBar.setBackgroundColor(bg);
        web = new WebView(this);
        web.setBackgroundColor(Color.TRANSPARENT);
        root.addView(topBar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0));
        root.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        root.addView(bottomBar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0));
        setContentView(root);

        ViewCompat.setOnApplyWindowInsetsListener(root, (v, insets) -> {
            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            Insets ime = insets.getInsets(WindowInsetsCompat.Type.ime());
            v.setPadding(bars.left, 0, bars.right, 0);
            setHeight(topBar, bars.top);
            setHeight(bottomBar, Math.max(bars.bottom, ime.bottom));
            return WindowInsetsCompat.CONSUMED;
        });

        boolean night = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        setBarIcons(night);

        final WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
                .setDomain(HOST)
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setTextZoom(100);

        web.addJavascriptInterface(new Bridge(), "MMAndroid");
        startTts();
        notifPermission = registerForActivityResult(new ActivityResultContracts.RequestPermission(),
                granted -> notifResult(granted && notificationsAllowed()));

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return loader.shouldInterceptRequest(request.getUrl());
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (HOST.equals(uri.getHost())) return false;
                // Outside links (GitHub, privacy policy, data source) open in the browser.
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, uri));
                } catch (ActivityNotFoundException ignored) {
                }
                return true;
            }
        });

        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState);
        } else {
            web.loadUrl(START_URL);
        }

        // Back closes an open menu or popup first; only then leaves the app.
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                web.evaluateJavascript("(window.mmBack&&window.mmBack())?'1':'0'", value -> {
                    if (!"\"1\"".equals(value)) finish();
                });
            }
        });
    }

    private void startTts() {
        tts = new TextToSpeech(this, status -> {
            if (status != TextToSpeech.SUCCESS || tts == null) {
                ttsState = "none";
                return;
            }
            int r = tts.setLanguage(Locale.SIMPLIFIED_CHINESE);
            if (r == TextToSpeech.LANG_MISSING_DATA) ttsState = "missing";
            else if (r == TextToSpeech.LANG_NOT_SUPPORTED) ttsState = "unsupported";
            else {
                ttsState = "ready";
                if (pendingText != null) {
                    speakNow(pendingText, pendingRate);
                    pendingText = null;
                }
            }
        });
        tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
            @Override public void onStart(String id) { }
            @Override public void onDone(String id) { speakEnded(); }
            @Override public void onError(String id) { speakEnded(); }
            @Override public void onStop(String id, boolean interrupted) { if (!interrupted) speakEnded(); }
        });
    }

    private void speakNow(String text, float rate) {
        if (tts == null) return;
        tts.setSpeechRate(rate);
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "xc" + (++utterance));
    }

    private void speakEnded() {
        runOnUiThread(() -> {
            if (web != null) web.evaluateJavascript("window.mmSpeakEnd&&mmSpeakEnd()", null);
        });
    }

    private static void setHeight(View view, int height) {
        ViewGroup.LayoutParams lp = view.getLayoutParams();
        if (lp.height != height) {
            lp.height = height;
            view.setLayoutParams(lp);
        }
    }

    /** Dark icons on light bars, light icons on dark bars. */
    private void setBarIcons(boolean darkBars) {
        WindowInsetsControllerCompat c = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        c.setAppearanceLightStatusBars(!darkBars);
        c.setAppearanceLightNavigationBars(!darkBars);
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }

    @Override
    protected void onResume() {
        super.onResume();
        Reminder.schedule(this);   // keeps the daily reminder alarm in place (no-op when reminders are off)
    }

    private boolean notificationsAllowed() {
        boolean permitted = Build.VERSION.SDK_INT < 33
                || ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        return permitted && NotificationManagerCompat.from(this).areNotificationsEnabled();
    }

    private void notifResult(boolean allowed) {
        if (web != null) web.evaluateJavascript("window.mmNotifResult&&mmNotifResult(" + allowed + ")", null);
    }

    private void openNotificationSettings() {
        Intent i = Build.VERSION.SDK_INT >= 26
                ? new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName())
                : new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getPackageName()));
        try {
            startActivity(i);
        } catch (ActivityNotFoundException ignored) {
        }
    }

    @Override
    protected void onPause() {
        if (tts != null) tts.stop();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
        }
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }

    /** Called from the page as window.MMAndroid. */
    private class Bridge {
        /** The page has drawn its first screen: the splash may go. */
        @JavascriptInterface
        public void ready() {
            pageReady = true;
        }

        /** Older pages: light or dark only. */
        @JavascriptInterface
        public void setTheme(final boolean dark) {
            runOnUiThread(() -> applyBars(fallback(dark), fallback(dark), dark));
        }

        /** Exact colours (#RRGGBB) for the status bar and the navigation bar, e.g. #000000 for true black. */
        @JavascriptInterface
        public void setBars(final String status, final String nav, final boolean dark) {
            runOnUiThread(() -> applyBars(parse(status, dark), parse(nav, dark), dark));
        }

        /** The phone's text size setting (1.0 = default); the page scales its text with it. */
        @JavascriptInterface
        public float fontScale() {
            return getResources().getConfiguration().fontScale;
        }

        /** Pronunciation: init | ready | missing (Chinese voice not installed) | unsupported | none (no engine). */
        @JavascriptInterface
        public String ttsStatus() {
            return ttsState;
        }

        /** Pronunciation: say a word or sentence in Mandarin; rate 1.0 = normal speed. */
        @JavascriptInterface
        public void speak(final String text, final float rate) {
            runOnUiThread(() -> {
                if ("ready".equals(ttsState)) speakNow(text, rate);
                else if ("init".equals(ttsState)) { pendingText = text; pendingRate = rate; }
            });
        }

        @JavascriptInterface
        public void stopSpeaking() {
            runOnUiThread(() -> { if (tts != null) tts.stop(); });
        }

        /** Opens the phone's text-to-speech settings, where a Chinese voice can be installed. */
        @JavascriptInterface
        public void openTtsSettings() {
            runOnUiThread(() -> {
                try {
                    startActivity(new Intent("com.android.settings.TTS_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                } catch (ActivityNotFoundException e) {
                    try {
                        startActivity(new Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA));
                    } catch (ActivityNotFoundException ignored) {
                    }
                }
            });
        }

        /** Daily study reminder: on/off, time, and the text to show (already in the study language). */
        @JavascriptInterface
        public void setReminder(boolean on, int hour, int minute, String title, String text, String channel) {
            Reminder.save(getApplicationContext(), on, hour, minute, title, text, channel);
        }

        /** The learner answered something today, so today's reminder is not needed. */
        @JavascriptInterface
        public void markStudied() {
            Reminder.markStudied(getApplicationContext());
        }

        /** Meditation days (闭关) as weekday numbers "0,3" (0 = Sunday): no reminder on those days. */
        @JavascriptInterface
        public void setRestDays(String days) {
            Reminder.setRestDays(getApplicationContext(), days);
        }

        /** granted | off */
        @JavascriptInterface
        public String notifStatus() {
            return notificationsAllowed() ? "granted" : "off";
        }

        /** Asks for the notification permission (Android 13+) or opens the settings; answers through mmNotifResult(). */
        @JavascriptInterface
        public void requestNotifications() {
            runOnUiThread(() -> {
                if (notificationsAllowed()) {
                    notifResult(true);
                } else if (Build.VERSION.SDK_INT >= 33
                        && ContextCompat.checkSelfPermission(MainActivity.this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS);
                } else {
                    openNotificationSettings();
                    notifResult(false);
                }
            });
        }

        @JavascriptInterface
        public void openNotifSettings() {
            runOnUiThread(MainActivity.this::openNotificationSettings);
        }

        /** Progress backup: put the backup code on the clipboard. */
        @JavascriptInterface
        public void copyText(final String text) {
            runOnUiThread(() -> {
                ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                if (cm != null) cm.setPrimaryClip(ClipData.newPlainText("XueCi Mandarin", text));
            });
        }

        /** Progress backup: share the backup code with another app (notes, email, chat, ...). */
        @JavascriptInterface
        public void shareText(final String subject, final String text) {
            runOnUiThread(() -> {
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType("text/plain");
                send.putExtra(Intent.EXTRA_SUBJECT, subject);
                send.putExtra(Intent.EXTRA_TEXT, text);
                try {
                    startActivity(Intent.createChooser(send, subject));
                } catch (ActivityNotFoundException ignored) {
                }
            });
        }

        /**
         * v1.16 share card: the page draws a PNG and hands it over as base64; it is written to the app's cache
         * (share/xueci-card.png, replaced each time) and offered through the system share sheet via FileProvider.
         * Nothing leaves the phone unless the learner picks an app.
         */
        @JavascriptInterface
        public boolean shareImage(final String base64Png, final String text) {
            try {
                byte[] png = Base64.decode(base64Png, Base64.DEFAULT);
                java.io.File dir = new java.io.File(getCacheDir(), "share");
                if (!dir.isDirectory() && !dir.mkdirs()) return false;
                java.io.File f = new java.io.File(dir, "xueci-card.png");
                try (java.io.FileOutputStream out = new java.io.FileOutputStream(f)) {
                    out.write(png);
                }
                final Uri uri = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".files", f);
                runOnUiThread(() -> {
                    Intent send = new Intent(Intent.ACTION_SEND);
                    send.setType("image/png");
                    send.putExtra(Intent.EXTRA_STREAM, uri);
                    send.putExtra(Intent.EXTRA_TEXT, text);
                    send.setClipData(ClipData.newRawUri("", uri));
                    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    try {
                        startActivity(Intent.createChooser(send, null));
                    } catch (ActivityNotFoundException ignored) {
                    }
                });
                return true;
            } catch (Exception e) {
                return false;
            }
        }

        /** Progress restore: read the clipboard (the app is in front, so Android allows it). */
        @JavascriptInterface
        public String pasteText() {
            final String[] out = {""};
            final CountDownLatch done = new CountDownLatch(1);
            runOnUiThread(() -> {
                try {
                    ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                    ClipData clip = cm != null ? cm.getPrimaryClip() : null;
                    if (clip != null && clip.getItemCount() > 0) {
                        CharSequence t = clip.getItemAt(0).coerceToText(MainActivity.this);
                        if (t != null) out[0] = t.toString();
                    }
                } catch (RuntimeException ignored) {
                } finally {
                    done.countDown();
                }
            });
            try {
                done.await(2, TimeUnit.SECONDS);
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
            return out[0];
        }
    }

    private static int fallback(boolean dark) {
        return Color.parseColor(dark ? "#23262C" : "#F4F5F7");
    }

    private static int parse(String hex, boolean dark) {
        try {
            return Color.parseColor(hex.trim());
        } catch (RuntimeException e) {
            return fallback(dark);
        }
    }

    private void applyBars(int statusColor, int navColor, boolean dark) {
        if (root == null) return;
        topBar.setBackgroundColor(statusColor);
        bottomBar.setBackgroundColor(navColor);
        root.setBackgroundColor(statusColor);
        setBarIcons(dark);
    }
}
