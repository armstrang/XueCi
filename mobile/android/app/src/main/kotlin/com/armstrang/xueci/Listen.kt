package com.armstrang.xueci

import android.content.ComponentName
import android.content.Intent
import android.speech.RecognitionService
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import org.json.JSONArray
import org.json.JSONObject

/**
 * Speaking practice inside the app: the phone's speech recognizer (SpeechRecognizer) without any window of its own.
 * The app shows the listening itself; while it listens, the loudness and what was heard so far go to Flutter as
 * events ("listenEv"); the end answers the pending call with the heard texts as a JSON list, "[]" when nothing was
 * heard, "!" when the phone has no recognizer, "denied" without the microphone permission, null when stopped early
 * or failed. Nothing is recorded or kept: the recognizer hands over text only.
 */
class Listen(private val act: MainActivity, private val event: (String) -> Unit) {
    private var rec: SpeechRecognizer? = null
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    private var done: ((String?) -> Unit)? = null

    fun available(): Boolean = SpeechRecognizer.isRecognitionAvailable(act)

    /** the recognizers to try in turn: Google's (it knows Mandarin), then the phone's default (Samsung's may not) */
    private fun services(): List<ComponentName?> {
        val list = mutableListOf<ComponentName?>()
        val found = act.packageManager.queryIntentServices(Intent(RecognitionService.SERVICE_INTERFACE), 0)
        found.firstOrNull { it.serviceInfo.packageName == "com.google.android.googlequicksearchbox" }
            ?.let { list.add(ComponentName(it.serviceInfo.packageName, it.serviceInfo.name)) }
        list.add(null)
        return list
    }

    private var tries: List<ComponentName?> = emptyList()
    private var heardAny = false

    fun start(done: (String?) -> Unit) {
        finish(null)
        if (!available()) {
            done("!")
            return
        }
        this.done = done
        tries = services()
        heardAny = false
        next()
    }

    /** a recognizer failed before hearing anything: the next one; none left = "!" (Flutter opens the phone's window) */
    private fun next() {
        if (done == null) return // stopped meanwhile
        val cn = tries.firstOrNull()
        if (tries.isEmpty()) {
            finish("!")
            return
        }
        tries = tries.drop(1)
        rec?.let {
            try {
                it.destroy()
            } catch (_: Exception) {
            }
        }
        val r = try {
            if (cn != null) SpeechRecognizer.createSpeechRecognizer(act, cn) else SpeechRecognizer.createSpeechRecognizer(act)
        } catch (_: Exception) {
            next()
            return
        }
        rec = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = send("ready")
            override fun onBeginningOfSpeech() = send("begin")
            override fun onRmsChanged(rmsdB: Float) {
                if (rmsdB > 2) heardAny = true
                send("rms", rmsdB.toDouble())
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() = send("end")
            override fun onError(error: Int) {
                send("err", error)
                when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> finish("denied")
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> finish("[]")
                    // language not there, busy, client or network trouble: the next recognizer, then the window
                    else -> if (heardAny) finish("[]") else main.post { next() }
                }
            }

            override fun onResults(results: Bundle?) {
                val heard = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: arrayListOf()
                finish(JSONArray(heard).toString())
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val p = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
                send("partial", p)
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
        }
        try {
            r.startListening(i)
        } catch (_: Exception) {
            main.post { next() }
        }
    }

    /** stop listening now: what was heard so far still comes back as the result */
    fun stop() {
        rec?.stopListening()
    }

    fun end() = finish(null)

    private fun send(t: String, v: Any? = null) {
        val o = JSONObject().put("t", t)
        if (v != null) o.put("v", v)
        event(o.toString())
    }

    private fun finish(answer: String?) {
        val d = done
        done = null
        rec?.let {
            try {
                it.cancel()
                it.destroy()
            } catch (_: Exception) {
            }
        }
        rec = null
        d?.invoke(answer)
    }
}
