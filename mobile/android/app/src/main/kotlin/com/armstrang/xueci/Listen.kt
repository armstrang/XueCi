package com.armstrang.xueci

import android.content.Intent
import android.os.Build
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
    private var done: ((String?) -> Unit)? = null

    fun available(): Boolean = SpeechRecognizer.isRecognitionAvailable(act)

    fun start(done: (String?) -> Unit) {
        finish(null)
        if (!available()) {
            done("!")
            return
        }
        this.done = done
        val r = SpeechRecognizer.createSpeechRecognizer(act)
        rec = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = send("ready")
            override fun onBeginningOfSpeech() = send("begin")
            override fun onRmsChanged(rmsdB: Float) = send("rms", rmsdB.toDouble())
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() = send("end")
            override fun onError(error: Int) {
                finish(
                    when (error) {
                        SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "[]"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "denied"
                        else -> null
                    },
                )
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
            // on the phone when it has the Mandarin model (no internet needed); otherwise its usual service
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, Build.VERSION.SDK_INT >= 33)
        }
        try {
            r.startListening(i)
        } catch (_: Exception) {
            finish(null)
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
