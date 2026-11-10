package com.armstrang.xueci

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper

/**
 * The background music: one looping piece per realm (res/raw/bgm_0…7.ogg, made by art/make_bgm.py). A new piece
 * fades in over the old one; the music gets quieter while a word is spoken ([duck]), is silent while the app
 * listens to the learner ([hush]) and while the app is not on screen. It never takes the audio focus: when another
 * app is already playing music, this one stays silent instead of playing over it.
 */
class Bgm(private val ctx: Context) {
    private val tracks = intArrayOf(
        R.raw.bgm_0, R.raw.bgm_1, R.raw.bgm_2, R.raw.bgm_3, R.raw.bgm_4, R.raw.bgm_5, R.raw.bgm_6, R.raw.bgm_7
    )
    private val main = Handler(Looper.getMainLooper())
    private var cur: MediaPlayer? = null
    private var old: MediaPlayer? = null
    private var track = -1      // the piece asked for (-1 = none)
    private var playing = -1    // the piece in [cur]
    private var pitch = 1f
    private var playingPitch = 1f
    private var vol = 0f        // the volume from Settings, 0…1
    private var curLevel = 0f   // the fades, 0…1
    private var oldLevel = 0f
    private var duckLevel = 1f
    private var ducked = false
    private var hushed = false
    private var resumed = false
    private var ticking = false

    private val tick = object : Runnable {
        override fun run() {
            ticking = false
            step()
        }
    }

    fun set(t: Int, v: Float, p: Float) {
        track = if (v <= 0f || t < 0 || t >= tracks.size) -1 else t
        vol = v.coerceIn(0f, 1f)
        pitch = p.coerceIn(0.5f, 2f)
        step()
    }

    fun duck(on: Boolean) {
        ducked = on
        step()
    }

    fun hush(on: Boolean) {
        hushed = on
        step()
    }

    fun resume() {
        resumed = true
        step()
    }

    fun pause() {
        resumed = false
        main.removeCallbacks(tick)
        ticking = false
        release(old)
        old = null
        oldLevel = 0f
        try {
            cur?.let { if (it.isPlaying) it.pause() }
        } catch (_: Exception) {
        }
    }

    fun end() {
        main.removeCallbacks(tick)
        ticking = false
        release(cur)
        release(old)
        cur = null
        old = null
        playing = -1
    }

    private fun release(p: MediaPlayer?) {
        try {
            p?.release()
        } catch (_: Exception) {
        }
    }

    private fun otherMusic(): Boolean = try {
        (ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager).isMusicActive
    } catch (_: Exception) {
        false
    }

    private fun open(t: Int, p: Float): MediaPlayer? = try {
        val afd = ctx.resources.openRawResourceFd(tracks[t])
        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
        )
        mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
        afd.close()
        mp.isLooping = true
        mp.setVolume(0f, 0f)
        mp.prepare()
        if (p != 1f) {
            try {
                mp.playbackParams = mp.playbackParams.setPitch(p)
            } catch (_: Exception) {
            }
        }
        mp.start()
        mp
    } catch (_: Exception) {
        null
    }

    /** one step of the fades (every 50 ms while something moves) */
    private fun step() {
        if (!resumed) return
        // a new piece: the one playing becomes the old one and fades out under it
        if (track != playing || (track >= 0 && pitch != playingPitch)) {
            val silent = cur == null || curLevel <= 0f
            if (track >= 0 && silent && old == null && otherMusic()) {
                // someone else's music is on: stay out of it (asked again on the next change or return to the app)
                release(cur)
                cur = null
                playing = -1
                curLevel = 0f
                return
            }
            release(old)
            old = cur
            oldLevel = curLevel
            cur = null
            curLevel = 0f
            playing = track
            playingPitch = pitch
            if (track >= 0) cur = open(track, pitch)
        }
        try {
            cur?.let { if (!it.isPlaying) it.start() }
        } catch (_: Exception) {
        }
        val duckTo = if (hushed) 0f else if (ducked) 0.3f else 1f
        var moving = false
        if (cur != null && curLevel < 1f) {
            curLevel = (curLevel + 0.035f).coerceAtMost(1f)
            moving = true
        }
        if (old != null) {
            oldLevel -= 0.035f
            if (oldLevel <= 0f) {
                release(old)
                old = null
                oldLevel = 0f
            } else {
                moving = true
            }
        }
        if (duckLevel != duckTo) {
            val d = if (duckTo < duckLevel) 0.14f else 0.05f // down fast, back up slowly
            duckLevel = if (duckTo < duckLevel) (duckLevel - d).coerceAtLeast(duckTo) else (duckLevel + d).coerceAtMost(duckTo)
            moving = true
        }
        val g = vol * duckLevel
        try {
            cur?.setVolume(g * curLevel * curLevel, g * curLevel * curLevel)
            old?.setVolume(g * oldLevel * oldLevel, g * oldLevel * oldLevel)
        } catch (_: Exception) {
        }
        if (moving && !ticking) {
            ticking = true
            main.postDelayed(tick, 50)
        }
    }
}
