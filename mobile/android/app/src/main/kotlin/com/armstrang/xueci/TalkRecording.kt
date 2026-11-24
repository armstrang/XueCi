package com.armstrang.xueci

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

/** One disposable BCT recording. Keep PCM in memory and delete playback files on discard. */
class TalkRecording(private val context: Context) {
    private class Capture(val input: AudioRecord, val finish: (Map<String, Any>?) -> Unit) {
        val stopping = AtomicBoolean()
    }

    private val main = Handler(Looper.getMainLooper())
    private var capture: Capture? = null
    private var pcm: ByteArray? = null
    private var playbackFile: File? = null
    private var player: MediaPlayer? = null
    private var requestedPosition = 0

    init {
        context.cacheDir.listFiles { file -> file.name.startsWith(PREFIX) }?.forEach { it.delete() }
    }

    @SuppressLint("MissingPermission") // MainActivity calls this only after granting RECORD_AUDIO.
    fun start(finish: (Map<String, Any>?) -> Unit) {
        if (capture != null) {
            finish(null)
            return
        }
        clear()
        val min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (min <= 0) {
            finish(null)
            return
        }
        val input = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(4096, min))
        } catch (_: Exception) {
            finish(null)
            return
        }
        try {
            input.startRecording()
            check(input.recordingState == AudioRecord.RECORDSTATE_RECORDING)
        } catch (_: Exception) {
            input.release()
            finish(null)
            return
        }
        val active = Capture(input, finish)
        capture = active
        Thread {
            val bytes = ByteArrayOutputStream()
            val chunk = ByteArray(3200)
            val maxBytes = RATE * 2 * 30
            try {
                while (!active.stopping.get() && bytes.size() < maxBytes) {
                    val read = input.read(chunk, 0, minOf(chunk.size, maxBytes - bytes.size()))
                    if (read <= 0) break
                    bytes.write(chunk, 0, read)
                }
            } finally {
                synchronized(active) {
                    if (!active.stopping.getAndSet(true)) runCatching { input.stop() }
                    input.release()
                }
                val data = bytes.toByteArray()
                main.post {
                    if (capture === active) {
                        capture = null
                        pcm = data.takeIf { it.size >= RATE / 5 }
                        active.finish(pcm?.let { mapOf("ms" to it.size * 1000 / (2 * RATE), "peaks" to peaks(it)) })
                    }
                }
            }
        }.start()
    }

    fun stop() {
        val active = capture ?: return
        synchronized(active) {
            if (!active.stopping.getAndSet(true)) runCatching { active.input.stop() }
        }
    }

    fun clear() {
        val active = capture
        stop()
        capture = null
        active?.finish?.invoke(null)
        pcm = null
        requestedPosition = 0
        player?.release()
        player = null
        playbackFile?.delete()
        playbackFile = null
    }

    fun raw(): File? {
        val data = pcm ?: return null
        val file = File.createTempFile(PREFIX, ".pcm", context.cacheDir)
        return try {
            file.writeBytes(data)
            file
        } catch (_: Exception) {
            file.delete()
            null
        }
    }

    fun position(): Int = player?.currentPosition ?: requestedPosition
    fun seek(milliseconds: Int) {
        requestedPosition = milliseconds.coerceAtLeast(0)
        player?.seekTo(requestedPosition)
    }
    fun pause() { if (player?.isPlaying == true) player?.pause() }

    fun play(): Boolean = try {
        var current = player
        if (current == null) {
            val data = checkNotNull(pcm)
            val file = File.createTempFile(PREFIX, ".wav", context.cacheDir)
            playbackFile = file
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray()).putInt(36 + data.size).put("WAVEfmt ".toByteArray())
            header.putInt(16).putShort(1).putShort(1).putInt(RATE).putInt(RATE * 2).putShort(2).putShort(16)
            header.put("data".toByteArray()).putInt(data.size)
            file.outputStream().use { it.write(header.array()); it.write(data) }
            current = MediaPlayer()
            player = current
            current.setDataSource(file.absolutePath)
            current.prepare()
            if (requestedPosition > 0) current.seekTo(requestedPosition)
        }
        current.start()
        true
    } catch (_: Exception) {
        player?.release()
        player = null
        playbackFile?.delete()
        playbackFile = null
        false
    }

    private fun peaks(audio: ByteArray): List<Int> {
        val samples = audio.size / 2
        return List(40) { bar ->
            var peak = 0
            for (i in samples * bar / 40 until samples * (bar + 1) / 40) {
                val value = (audio[2 * i].toInt() and 255) or (audio[2 * i + 1].toInt() shl 8)
                peak = maxOf(peak, kotlin.math.abs(value))
            }
            peak * 100 / 32768
        }
    }

    companion object {
        const val RATE = 16000
        private const val PREFIX = "bct-voice-"
    }
}
