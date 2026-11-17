package com.armstrang.xueci

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper

/**
 * The tone check: the app records the learner's voice itself (the speech recognizer hands over text only, and the
 * microphone can't serve both at once). 16 kHz mono 16-bit PCM, kept in memory, handed to Flutter when it stops,
 * then forgotten: nothing is written to a file or sent anywhere. Stops by itself after [limit] ms.
 */
class Rec {
    private val main = Handler(Looper.getMainLooper())
    private var ar: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile private var running = false
    private var buf = java.io.ByteArrayOutputStream()
    private var waiting: ((ByteArray?) -> Unit)? = null

    @SuppressLint("MissingPermission") // asked by the caller (micGranted)
    fun start(limit: Long): Boolean {
        cancel()
        val min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (min <= 0) return false
        val r = try {
            AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(min, RATE))
        } catch (_: Exception) {
            return false
        }
        if (r.state != AudioRecord.STATE_INITIALIZED) {
            r.release()
            return false
        }
        ar = r
        buf = java.io.ByteArrayOutputStream()
        running = true
        try {
            r.startRecording()
        } catch (_: Exception) {
            cancel()
            return false
        }
        val maxBytes = (limit.coerceIn(1000L, 30000L) * RATE / 1000 * 2).toInt()
        thread = Thread {
            val chunk = ByteArray(2048)
            while (running) {
                val n = try { r.read(chunk, 0, chunk.size) } catch (_: Exception) { -1 }
                if (n < 0) break
                if (n > 0) synchronized(this) { buf.write(chunk, 0, n) }
                if (buf.size() >= maxBytes) break
            }
            running = false
            main.post { finish() }
        }.also { it.start() }
        return true
    }

    /** stop and hand over what was recorded (null when nothing was) */
    fun stop(done: (ByteArray?) -> Unit) {
        if (ar == null) {
            done(pending)
            pending = null
            return
        }
        waiting = done
        if (!running) finish() else running = false
    }

    private fun finish() {
        val r = ar ?: return
        ar = null
        try {
            r.stop()
        } catch (_: Exception) {
        }
        r.release()
        val out = synchronized(this) { buf.toByteArray() }
        buf = java.io.ByteArrayOutputStream()
        val w = waiting
        waiting = null
        if (w != null) w(if (out.isEmpty()) null else out) else pending = out
    }

    /** a recording that stopped by itself before Flutter asked: kept for the next stop */
    private var pending: ByteArray? = null

    fun cancel() {
        running = false
        thread = null
        val r = ar
        ar = null
        if (r != null) {
            try {
                r.stop()
            } catch (_: Exception) {
            }
            r.release()
        }
        pending = null
        waiting?.invoke(null)
        waiting = null
    }

    companion object {
        const val RATE = 16000
    }
}
