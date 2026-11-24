package com.armstrang.xueci

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.AudioFormat
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.File
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import org.json.JSONArray
import org.json.JSONObject

/**
 * Speaking practice inside the app: the phone's speech recognizer (SpeechRecognizer), no window of its own.
 * One tap starts, a second tap stops (or the limit passes: 15 s for a word or a sentence, up to a few minutes for an
 * HSKK answer or a text read aloud): the recognizer stops by itself at every pause, so between the
 * taps it is started again quietly and the pieces are joined. While it listens, the loudness and what was heard so
 * far go to Flutter as events ("listenEv": ready, rms, partial, err); the end answers the pending call with the heard
 * texts as a JSON list (best guess first), "[]" when nothing was heard, "!" when no recognizer works here (Flutter
 * then opens the phone's window), "denied" without the microphone permission. Nothing is recorded or kept: the
 * recognizer hands over text only. It is asked to work offline first (the phone's own Mandarin pack); a recognizer
 * that can't (no pack) is asked again without that wish.
 *
 * The recognizer plays its own "ding" at every start and stop, and it is restarted at every pause, so a long answer
 * rang many times. While listening the media volume is muted ([Quiet]) and given back a moment after the end.
 */
class Listen(private val act: Context, private val event: (String) -> Unit) {
    private var rec: SpeechRecognizer? = null
    private val main = Handler(Looper.getMainLooper())
    private var done: ((String?) -> Unit)? = null

    // the recognizers to try (Google's knows Mandarin; the phone's default may not), the one that works
    private var tries: List<ComponentName?> = emptyList()
    private var service: ComponentName? = null
    private var serviceFound = false

    private val pieces = mutableListOf<String>() // the best guess of each finished piece
    private val talkHypotheses = TalkHypotheses()
    private var conversation = false
    private var lastAlts: List<String> = emptyList() // the other guesses of the last piece
    private var stopping = false
    private var startedAt = 0L
    private var heardAny = false
    private var limitMs = LIMIT_MS
    private var session = 0L
    private var offline = true // ask for the phone's own language pack first

    private val quiet = Quiet(act.applicationContext)
    private var recording: File? = null
    private var source: ParcelFileDescriptor? = null

    fun available(): Boolean = SpeechRecognizer.isRecognitionAvailable(act)

    fun canTranscribeRecording(): Boolean =
        Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isOnDeviceRecognitionAvailable(act)

    /** at app start: give back the volume if the app was killed while it was muted */
    fun recover() = quiet.recover()

    /** the app closes: the volume comes back at once */
    fun release() {
        finish(null)
        quiet.off(0)
    }

    private fun services(): List<ComponentName?> {
        val list = mutableListOf<ComponentName?>()
        val found = act.packageManager.queryIntentServices(Intent(RecognitionService.SERVICE_INTERFACE), 0)
        found.firstOrNull { it.serviceInfo.packageName == "com.google.android.googlequicksearchbox" }
            ?.let { list.add(ComponentName(it.serviceInfo.packageName, it.serviceInfo.name)) }
        list.add(null)
        return list
    }

    fun start(limit: Long = LIMIT_MS, conversation: Boolean = false, audio: File? = null, done: (String?) -> Unit) {
        finish(null)
        session++
        if (audio == null && !available() || audio != null && !canTranscribeRecording()) {
            audio?.delete()
            done("!")
            return
        }
        this.done = done
        recording = audio
        pieces.clear()
        talkHypotheses.reset()
        this.conversation = conversation
        lastAlts = emptyList()
        stopping = false
        heardAny = false
        serviceFound = false
        startedAt = SystemClock.uptimeMillis()
        limitMs = limit.coerceIn(3000L, if (conversation) TALK_MAX_MS else MAX_MS)
        offline = true
        tries = if (audio != null) listOf(null) else services()
        quiet.on()
        main.postDelayed(this.limit, limitMs)
        nextService()
    }

    private val limit = Runnable { stop() }

    /** stop listening: what was heard so far comes back as the result */
    fun stop() {
        if (done == null || stopping) return
        stopping = true
        try {
            rec?.stopListening()
        } catch (_: Exception) {
        }
        // a recognizer that never answers the stop: end with what we have
        main.postDelayed(late, 2500)
    }

    private val late = Runnable { finish(answer()) }

    private fun schedule(delay: Long = 0, action: () -> Unit) {
        val current = session
        main.postDelayed({
            if (done != null && session == current) action()
        }, delay)
    }

    fun end() = finish(null)

    fun cancelRecordingTranscription() { if (recording != null) finish(null) }

    /** the recognizer before failed without hearing anything: the next one; none left = "!" */
    private fun nextService() {
        if (done == null) return
        if (tries.isEmpty()) {
            finish("!")
            return
        }
        service = tries.first()
        tries = tries.drop(1)
        listen()
    }

    /** one piece of listening (the recognizer stops at a pause; [restart] keeps going until the tap or the limit) */
    private fun listen() {
        if (done == null) return
        if (stopping) {
            finish(answer())
            return
        }
        destroy()
        val cn = service
        val r = try {
            if (recording != null && Build.VERSION.SDK_INT >= 33) SpeechRecognizer.createOnDeviceSpeechRecognizer(act)
            else if (cn != null) SpeechRecognizer.createSpeechRecognizer(act, cn)
            else SpeechRecognizer.createSpeechRecognizer(act)
        } catch (_: Exception) {
            schedule { nextService() }
            return
        }
        rec = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                serviceFound = true
                send("ready")
            }

            override fun onBeginningOfSpeech() = send("begin")
            override fun onRmsChanged(rmsdB: Float) {
                if (rmsdB > 2) heardAny = true
                send("rms", rmsdB.toDouble())
            }

            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                if (rec !== r) return
                send("err", error)
                if (recording != null) {
                    finish(if (pieces.isEmpty()) "!" else answer())
                    return
                }
                when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> finish("denied")
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> restart()
                    else -> when {
                        // no offline pack (or the recognizer won't work offline): the same one again, online allowed
                        offline && !heardAny && pieces.isEmpty() && error in OFFLINE_ERRORS -> {
                            offline = false
                            schedule(120) { listen() }
                        }
                        // this recognizer can't do it here (no Mandarin, busy, offline): the next one
                        !serviceFound && !heardAny && pieces.isEmpty() -> schedule { nextService() }
                        else -> restart()
                    }
                }
            }

            override fun onSegmentResults(segmentResults: Bundle) {
                if (rec !== r || recording == null) return
                recordSegment(segmentResults)
            }

            override fun onEndOfSegmentedSession() {
                if (rec === r && recording != null) finish(answer())
            }

            private fun recordSegment(results: Bundle?) {
                if (rec !== r) return
                val heard = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: arrayListOf()
                val best = heard.firstOrNull()?.trim().orEmpty()
                if (best.isNotEmpty()) {
                    pieces.add(best)
                    if (conversation) talkHypotheses.add(heard)
                    lastAlts = heard.drop(1).map { it.trim() }.filter { it.isNotEmpty() }
                    send("partial", pieces.joinToString(""))
                }
            }

            override fun onResults(results: Bundle?) {
                if (rec !== r) return
                // Captured audio requires a service that supports audio input. A live-mic
                // result must never be credited as if it came from the saved take.
                if (recording != null) {
                    finish(if (pieces.isEmpty()) "!" else answer())
                    return
                }
                recordSegment(results)
                restart()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (rec !== r) return
                val p = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
                send("partial", pieces.joinToString("") + p)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, act.packageName)
            if (offline) putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            // ask for longer pauses before it stops by itself (some recognizers ignore this; we restart anyway)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 15000L)
        }
        try {
            source?.close()
            source = recording?.let { ParcelFileDescriptor.open(it, ParcelFileDescriptor.MODE_READ_ONLY) }
            if (Build.VERSION.SDK_INT >= 33) source?.let {
                i.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, it)
                i.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                i.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                i.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, TalkRecording.RATE)
                i.putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
            }
            r.startListening(i)
        } catch (_: Exception) {
            schedule { nextService() }
        }
    }

    /** a piece ended: listen on until the tap or the limit, otherwise answer */
    private fun restart() {
        if (done == null) return
        if (stopping || SystemClock.uptimeMillis() - startedAt >= limitMs - 300) {
            finish(answer())
            return
        }
        schedule(120) { listen() }
    }

    /** Complete hypotheses in rank order, with an expanded beam for conversation. */
    private fun answer(): String {
        if (pieces.isEmpty()) return "[]"
        if (conversation) return JSONArray(talkHypotheses.answers()).toString()
        val head = pieces.dropLast(1).joinToString("")
        val all = mutableListOf(pieces.joinToString(""))
        for (a in lastAlts) all.add(head + a)
        return JSONArray(all.distinct()).toString()
    }

    private fun send(t: String, v: Any? = null) {
        val o = JSONObject().put("t", t)
        if (v != null) o.put("v", v)
        event(o.toString())
    }

    private fun destroy() {
        val r = rec ?: return
        rec = null
        try {
            r.cancel()
            r.destroy()
        } catch (_: Exception) {
        }
    }

    private fun finish(answer: String?) {
        main.removeCallbacks(limit)
        main.removeCallbacks(late)
        val d = done
        done = null
        destroy()
        runCatching { source?.close() }
        source = null
        recording?.delete()
        recording = null
        quiet.off(700) // the recognizer's last "ding" is played a moment after it is stopped
        d?.invoke(answer)
    }

    companion object {
        const val LIMIT_MS = 15000L
        private const val TALK_MAX_MS = 30000L
        const val MAX_MS = 300000L // five minutes at most, whatever is asked
        // what a recognizer answers when it can't work offline here (language pack missing or not offered)
        private val OFFLINE_ERRORS = setOf(
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_SERVER, SpeechRecognizer.ERROR_CLIENT,
            12 /* ERROR_LANGUAGE_NOT_SUPPORTED */, 13 /* ERROR_LANGUAGE_UNAVAILABLE */,
        )
    }
}

/**
 * Mutes the media volume (the stream the recognizer's "ding" is played on) while the app listens. MUTE keeps the
 * volume setting, only the sound goes. If the phone's media was already muted nothing is touched. The ring and
 * notification streams are left alone on purpose: on many phones they share the ringer, and muting them could
 * leave the phone silent. [recover] gives the volume back after a crash, using what was written down.
 */
private class Quiet(ctx: Context) {
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val prefs = ctx.getSharedPreferences("quiet", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private var muted = false
    private val unmute = Runnable { give() }

    fun on() {
        main.removeCallbacks(unmute)
        if (muted) return
        try {
            if (am.isStreamMute(AudioManager.STREAM_MUSIC)) return
            // written down first: if the app dies now, the next start gives the volume back
            prefs.edit().putBoolean("music", true).commit()
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_MUTE, 0)
            muted = true
        } catch (_: Exception) {
            prefs.edit().remove("music").apply()
        }
    }

    fun off(delayMs: Long) {
        main.removeCallbacks(unmute)
        if (!muted) return
        if (delayMs <= 0) give() else main.postDelayed(unmute, delayMs)
    }

    fun recover() {
        if (prefs.getBoolean("music", false)) give(force = true)
    }

    private fun give(force: Boolean = false) {
        if (!muted && !force) return
        muted = false
        try {
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, 0)
        } catch (_: Exception) {
        }
        prefs.edit().remove("music").apply()
    }
}
