package com.armstrang.xueci

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.webkit.WebViewAssetLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Locale

/**
 * The Flutter app's Android side: the services the WebView app (v1.x) reached through its MMAndroid bridge, on the
 * method channel "xueci/native" — speech, the daily reminder, sharing, the home-screen widget, donations (Donate.kt) —
 * plus the one-time move
 * of v1.x progress (read by a hidden WebView on v1.x's origin, see assets/legacy.html).
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var tts: TextToSpeech? = null
    @Volatile private var ttsState = "init" // init | ready | missing | unsupported | none
    private var pendingText: String? = null
    private var pendingRate = 1f
    private var utterance = 0
    @Volatile private var ready = false
    private var startedAt = 0L
    private var legacyView: WebView? = null
    private val main = Handler(Looper.getMainLooper())
    private var donate: Donate? = null
    private var listenResult: MethodChannel.Result? = null

    /** Google Play Billing, connected the first time the donation sheet asks */
    private fun don(): Donate = donate ?: Donate(this).also { donate = it }

    override fun onCreate(savedInstanceState: Bundle?) {
        startedAt = SystemClock.uptimeMillis()
        // the splash stays until Home is on screen (Native.ready from the first frame), 2.5 s at most
        installSplashScreen().setKeepOnScreenCondition { !ready && SystemClock.uptimeMillis() - startedAt < 2500 }
        super.onCreate(savedInstanceState)
        startTts()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xueci/native")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)
                "legacy" -> readLegacy { result.success(it) }
                "ready" -> { ready = true; result.success(null) }
                "ttsStatus" -> result.success(ttsState)
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val rate = (call.argument<Double>("rate") ?: 0.9).toFloat()
                    when (ttsState) {
                        "ready" -> speakNow(text, rate)
                        "init" -> { pendingText = text; pendingRate = rate }
                    }
                    result.success(null)
                }
                "stopSpeaking" -> { tts?.stop(); result.success(null) }
                "openTtsSettings" -> { openTtsSettings(); result.success(null) }
                "setReminder" -> {
                    val o = JSONObject(call.arguments as String)
                    Reminder.save(
                        applicationContext, o.optBoolean("on"), o.optInt("h", 19), o.optInt("m", 0),
                        o.optString("title"), o.optString("body"), o.optString("channel"),
                    )
                    result.success(null)
                }
                "markStudied" -> { Reminder.markStudied(applicationContext); result.success(null) }
                "setRestDays" -> {
                    val a = JSONArray(call.arguments as String)
                    Reminder.setRestDays(applicationContext, (0 until a.length()).joinToString(",") { a.optInt(it).toString() })
                    result.success(null)
                }
                "notifStatus" -> result.success(if (notificationsAllowed()) "granted" else "off")
                "requestNotifications" -> { requestNotifications(); result.success(null) }
                "openNotifSettings" -> { openNotificationSettings(); result.success(null) }
                "canRemind" -> result.success(true)
                "shareText" -> result.success(shareText(call.arguments as String))
                "shareImage" -> result.success(shareImage(call.argument<ByteArray>("png"), call.argument<String>("text") ?: ""))
                "openUrl" -> { openUrl(call.arguments as String); result.success(null) }
                "setWidget" -> { XueciWidget.save(applicationContext, call.arguments as String); result.success(null) }
                "donProducts" -> {
                    val a = JSONArray(call.arguments as String)
                    don().products((0 until a.length()).map { a.getString(it) }) { main.post { result.success(it) } }
                }
                "donBuy" -> don().buy(call.arguments as String) { main.post { result.success(it) } }
                "canListen" -> result.success(canListen())
                "listen" -> listen(call.arguments as? String ?: "", result)
                else -> result.notImplemented()
            }
        }
    }

    // ---------------------------------------------------------------- speaking practice
    private fun recognizeIntent(prompt: String) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
        putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf("zh-CN"))
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        if (prompt.isNotEmpty()) putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
    }

    private fun canListen(): Boolean =
        recognizeIntent("").resolveActivity(packageManager) != null

    /** the phone's recognizer in its own window; answers the heard texts as a JSON list, "[]" when nothing was heard,
     *  "!" when the phone has no recognizer, null when it was closed */
    private fun listen(prompt: String, result: MethodChannel.Result) {
        listenResult?.success(null)
        listenResult = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(recognizeIntent(prompt), REQ_LISTEN)
        } catch (e: ActivityNotFoundException) {
            listenResult = null
            result.success("!")
        }
    }

    @Deprecated("startActivityForResult is enough here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_LISTEN) return
        val r = listenResult ?: return
        listenResult = null
        if (resultCode != RESULT_OK) {
            r.success(null)
            return
        }
        val heard = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS) ?: arrayListOf()
        r.success(JSONArray(heard).toString())
    }

    // ---------------------------------------------------------------- v1.x progress
    /**
     * v1.x kept its progress in the WebView storage of https://appassets.androidplatform.net (IndexedDB and
     * localStorage). A hidden WebView on that same origin reads it once and hands it over as JSON (key → text).
     * No WebView data on the phone (a new install): nothing to read, answered at once.
     */
    @SuppressLint("SetJavaScriptEnabled")
    private fun readLegacy(done: (String?) -> Unit) {
        val data = File(applicationInfo.dataDir, "app_webview")
        if (!data.isDirectory) {
            done(null)
            return
        }
        var answered = false
        fun answer(s: String?) {
            main.post {
                if (answered) return@post
                answered = true
                done(s)
                legacyView?.destroy()
                legacyView = null
            }
        }
        try {
            val host = "appassets.androidplatform.net"
            val loader = WebViewAssetLoader.Builder()
                .setDomain(host)
                .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
                .build()
            val w = WebView(this)
            legacyView = w
            w.settings.javaScriptEnabled = true
            w.settings.domStorageEnabled = true
            w.settings.allowFileAccess = false
            w.settings.allowContentAccess = false
            w.addJavascriptInterface(object {
                @JavascriptInterface
                fun done(json: String) = answer(json)
            }, "XcLegacy")
            w.webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                    loader.shouldInterceptRequest(request.url)

                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true
            }
            w.loadUrl("https://$host/assets/legacy.html")
            main.postDelayed({ answer("!") }, 8000) // failed: the app tries again at the next start
        } catch (e: Exception) {
            answer("!")
        }
    }

    // ---------------------------------------------------------------- speech
    private fun startTts() {
        tts = TextToSpeech(this) { status ->
            val t = tts
            if (status != TextToSpeech.SUCCESS || t == null) {
                ttsState = "none"
                return@TextToSpeech
            }
            ttsState = when (t.setLanguage(Locale.SIMPLIFIED_CHINESE)) {
                TextToSpeech.LANG_MISSING_DATA -> "missing"
                TextToSpeech.LANG_NOT_SUPPORTED -> "unsupported"
                else -> "ready"
            }
            if (ttsState == "ready") {
                pendingText?.let { speakNow(it, pendingRate) }
                pendingText = null
            }
            main.post { if (::channel.isInitialized) channel.invokeMethod("ttsReady", ttsState) }
        }
    }

    private fun speakNow(text: String, rate: Float) {
        val t = tts ?: return
        t.setSpeechRate(rate)
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "xc" + (++utterance))
    }

    private fun openTtsSettings() {
        try {
            startActivity(Intent("com.android.settings.TTS_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            try {
                startActivity(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))
            } catch (_: ActivityNotFoundException) {
            }
        }
    }

    // ---------------------------------------------------------------- notifications
    private fun notificationsAllowed(): Boolean {
        val permitted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return permitted && NotificationManagerCompat.from(this).areNotificationsEnabled()
    }

    private fun notifResult(allowed: Boolean) = channel.invokeMethod("notifResult", allowed)

    private fun requestNotifications() {
        if (notificationsAllowed()) {
            notifResult(true)
        } else if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIF_REQUEST)
        } else {
            openNotificationSettings()
            notifResult(false)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIF_REQUEST) notifResult(notificationsAllowed())
    }

    private fun openNotificationSettings() {
        val i = if (Build.VERSION.SDK_INT >= 26) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        try {
            startActivity(i)
        } catch (_: ActivityNotFoundException) {
        }
    }

    // ---------------------------------------------------------------- sharing and links
    private fun shareText(text: String): Boolean {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        return try {
            startActivity(Intent.createChooser(send, null))
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    /** the share card: written to the cache (share/xueci-card.png) and offered through the share sheet */
    private fun shareImage(png: ByteArray?, text: String): Boolean {
        if (png == null) return false
        return try {
            val dir = File(cacheDir, "share")
            if (!dir.isDirectory && !dir.mkdirs()) return false
            val f = File(dir, "xueci-card.png")
            f.writeBytes(png)
            val uri = FileProvider.getUriForFile(this, "$packageName.files", f)
            val send = Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_TEXT, text)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            send.clipData = ClipData.newRawUri("", uri)
            startActivity(Intent.createChooser(send, null))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openUrl(url: String) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
        }
    }

    // ---------------------------------------------------------------- life cycle
    override fun onResume() {
        super.onResume()
        Reminder.schedule(this) // keeps the daily reminder alarm in place (no-op when reminders are off)
    }

    override fun onPause() {
        tts?.stop()
        super.onPause()
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        legacyView?.destroy()
        legacyView = null
        donate?.end()
        donate = null
        super.onDestroy()
    }

    companion object {
        private const val REQ_LISTEN = 7301
        private const val NOTIF_REQUEST = 7
    }
}
