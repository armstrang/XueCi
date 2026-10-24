package com.armstrang.xueci

import android.content.ComponentName
import android.content.Intent
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
 * One tap starts, a second tap stops (or 15 s pass): the recognizer stops by itself at every pause, so between the
 * taps it is started again quietly and the pieces are joined. While it listens, the loudness and what was heard so
 * far go to Flutter as events ("listenEv": ready, rms, partial, err); the end answers the pending call with the heard
 * texts as a JSON list (best guess first), "[]" when nothing was heard, "!" when no recognizer works here (Flutter
 * then opens the phone's window), "denied" without the microphone permission. Nothing is recorded or kept: the
 * recognizer hands over text only.
 */
class Listen(private val act: MainActivity, private val event: (String) -> Unit) {
    private var rec: SpeechRecognizer? = null
    private val main = Handler(Looper.getMainLooper())
    private var done: ((String?) -> Unit)? = null

    // the recognizers to try (Google's knows Mandarin; the phone's default may not), the one that works
    private var tries: List<ComponentName?> = emptyList()
    private var service: ComponentName? = null
    private var serviceFound = false

    private val pieces = mutableListOf<String>() // the best guess of each finished piece
    private var lastAlts: List<String> = emptyList() // the other guesses of the last piece
    private var stopping = false
    private var startedAt = 0L
    private var heardAny = false

    fun available(): Boolean = SpeechRecognizer.isRecognitionAvailable(act)

    private fun services(): List<ComponentName?> {
        val list = mutableListOf<ComponentName?>()
        val found = act.packageManager.queryIntentServices(Intent(RecognitionService.SERVICE_INTERFACE), 0)
        found.firstOrNull { it.serviceInfo.packageName == "com.google.android.googlequicksearchbox" }
            ?.let { list.add(ComponentName(it.serviceInfo.packageName, it.serviceInfo.name)) }
        list.add(null)
        return list
    }

    fun start(done: (String?) -> Unit) {
        finish(null)
        if (!available()) {
            done("!")
            return
        }
        this.done = done
        pieces.clear()
        lastAlts = emptyList()
        stopping = false
        heardAny = false
        serviceFound = false
        startedAt = SystemClock.uptimeMillis()
        tries = services()
        main.postDelayed(limit, LIMIT_MS)
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

    fun end() = finish(null)

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
            if (cn != null) SpeechRecognizer.createSpeechRecognizer(act, cn) else SpeechRecognizer.createSpeechRecognizer(act)
        } catch (_: Exception) {
            main.post { nextService() }
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
                when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> finish("denied")
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> restart()
                    else -> when {
                        // this recognizer can't do it here (no Mandarin, busy, offline): the next one
                        !serviceFound && !heardAny && pieces.isEmpty() -> main.post { nextService() }
                        else -> restart()
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                if (rec !== r) return
                val heard = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: arrayListOf()
                val best = heard.firstOrNull()?.trim().orEmpty()
                if (best.isNotEmpty()) {
                    pieces.add(best)
                    lastAlts = heard.drop(1).map { it.trim() }.filter { it.isNotEmpty() }
                    send("partial", pieces.joinToString(""))
                }
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
            // ask for longer pauses before it stops by itself (some recognizers ignore this; we restart anyway)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 15000L)
        }
        try {
            r.startListening(i)
        } catch (_: Exception) {
            main.post { nextService() }
        }
    }

    /** a piece ended: listen on until the tap or the limit, otherwise answer */
    private fun restart() {
        if (done == null) return
        if (stopping || SystemClock.uptimeMillis() - startedAt >= LIMIT_MS - 300) {
            finish(answer())
            return
        }
        main.postDelayed({ listen() }, 120)
    }

    /** the joined best guesses first, then the same with the last piece's other guesses */
    private fun answer(): String {
        if (pieces.isEmpty()) return "[]"
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
        d?.invoke(answer)
    }

    companion object {
        const val LIMIT_MS = 15000L
    }
}
