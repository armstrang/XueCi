package com.armstrang.xueci;

import android.annotation.SuppressLint;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
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
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.webkit.WebViewAssetLoader;

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

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
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
    protected void onDestroy() {
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }

    /** Called from the page as window.MMAndroid. */
    private class Bridge {
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
