package com.jorgi.merdekamandarin;

import android.annotation.SuppressLint;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewAssetLoader;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Hosts the XueCi Mandarin page (assets/index.html) in a WebView.
 * The page is served from https://appassets.androidplatform.net so it gets a stable origin
 * and localStorage (study progress, theme, language) survives app restarts and updates.
 */
public class MainActivity extends AppCompatActivity {

    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/assets/index.html";

    private WebView web;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        web = new WebView(this);
        web.setBackgroundColor(Color.TRANSPARENT);
        setContentView(web);

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
                // Outside links (e.g. the data source on GitHub) open in the browser.
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

    /** Lets the page match the status and navigation bars to its theme. */
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
        return Color.parseColor(dark ? "#0F1218" : "#F4F5F7");
    }

    private static int parse(String hex, boolean dark) {
        try {
            return Color.parseColor(hex.trim());
        } catch (RuntimeException e) {
            return fallback(dark);
        }
    }

    private void applyBars(int statusColor, int navColor, boolean dark) {
        Window w = getWindow();
        w.setStatusBarColor(statusColor);
        w.setNavigationBarColor(navColor);
        View decor = w.getDecorView();
        int flags = decor.getSystemUiVisibility();
        if (dark) {
            flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) flags &= ~View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        } else {
            flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        }
        decor.setSystemUiVisibility(flags);
    }
}
