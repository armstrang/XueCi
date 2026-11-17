package com.armstrang.xueci

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.text.style.UnderlineSpan
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.ceil
import kotlin.math.max

/**
 * v1.4 the word widget (Josh: for memorising, no quiz): one word of the realm's HSK level — the hanzi drawn in the
 * app's own serif, its pinyin in tone colours, the meaning, and on a tall widget the example sentence. ‹ › step through
 * the words of a unit, the small arrows at the top through the units; the place is kept per widget. A tap on the hanzi
 * opens that word in the app's List.
 *
 * The words come from the app (App.syncWords) as one JSON file in the app's files folder, written only when the level
 * or the study language changes. Light = "Kertas" (paper), dark = "Malam" (night): backgrounds and text colours are
 * resources with -night variants; the pinyin's tone colours are set per mode (setColorInt on Android 12+). Nothing
 * leaves the phone.
 */
class XueciWordWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) {
        for (id in ids) draw(c, m, id)
    }

    override fun onAppWidgetOptionsChanged(c: Context, m: AppWidgetManager, id: Int, o: Bundle) {
        draw(c, m, id)
    }

    override fun onDeleted(c: Context, ids: IntArray) {
        val e = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        for (id in ids) e.remove("i$id").remove("l$id")
        e.apply()
    }

    override fun onReceive(c: Context, i: Intent) {
        super.onReceive(c, i)
        if (i.action != STEP) return
        val id = i.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val d = load(c) ?: return
        step(c, d, id, i.getIntExtra("d", 0))
        draw(c, AppWidgetManager.getInstance(c), id)
    }

    class Word(val u: Int, val h: String, val syl: List<String>, val tones: String, val m: String, val z: String, val tr: String)

    class Data(val lv: Int, val realm: String, val unit: String, val unitShort: String, val labels: List<String>, val w: List<Word>) {
        /** each unit's first index and size, in list order */
        val units: List<Pair<Int, Int>> = run {
            val out = mutableListOf<Pair<Int, Int>>()
            var start = 0
            for (k in 1..w.size) {
                if (k == w.size || w[k].u != w[start].u) {
                    out.add(start to (k - start))
                    start = k
                }
            }
            out
        }

        fun unitOf(i: Int): Int = units.indexOfFirst { i >= it.first && i < it.first + it.second }.coerceAtLeast(0)
    }

    companion object {
        const val STEP = "com.armstrang.xueci.WORD_STEP"
        const val EXTRA_WORD = "xueci_word"
        private const val PREFS = "wword"
        private const val FILE = "widget_words.json"
        private var cache: Data? = null
        private var cacheAt = 0L
        private var serif: Typeface? = null

        fun save(c: Context, json: String) {
            synchronized(this) {
                File(c.filesDir, FILE).writeText(json)
                cache = null
            }
            update(c)
        }

        fun update(c: Context) {
            val m = AppWidgetManager.getInstance(c)
            val ids = m.getAppWidgetIds(ComponentName(c, XueciWordWidget::class.java)) ?: return
            for (id in ids) draw(c, m, id)
        }

        private fun load(c: Context): Data? {
            synchronized(this) { return read(c) }
        }

        private fun read(c: Context): Data? {
            val f = File(c.filesDir, FILE)
            if (!f.exists()) return null
            if (cache != null && f.lastModified() == cacheAt) return cache
            try {
                val o = JSONObject(f.readText())
                val a = o.getJSONArray("w")
                val words = ArrayList<Word>(a.length())
                for (k in 0 until a.length()) {
                    val x = a.getJSONArray(k)
                    words.add(
                        Word(
                            x.optInt(0, 1), x.optString(1), x.optString(2).split(' ').filter { it.isNotEmpty() },
                            x.optString(3), x.optString(4), x.optString(5), x.optString(6),
                        )
                    )
                }
                if (words.isEmpty()) return null
                val lb = o.optJSONArray("lb") ?: JSONArray()
                cache = Data(
                    o.optInt("l", 1), o.optString("r", ""), o.optString("u", "Unit"), o.optString("us", "U"),
                    (0 until 4).map { lb.optString(it, "") }, words,
                )
                cacheAt = f.lastModified()
                return cache
            } catch (_: Exception) {
                return null
            }
        }

        /** the widget's place: the word index, kept per widget and reset when the level changes */
        private fun place(c: Context, d: Data, id: Int): Int {
            val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val i = p.getInt("i$id", 0)
            return if (p.getInt("l$id", -1) != d.lv || i !in d.w.indices) 0 else i
        }

        /** d = ±1 word inside the unit (round), ±2 unit (round, to its first word) */
        private fun step(c: Context, d: Data, id: Int, dir: Int) {
            val i = place(c, d, id)
            val k = d.unitOf(i)
            val (start, size) = d.units[k]
            val n = when (dir) {
                1, -1 -> start + Math.floorMod(i - start + dir, size)
                2, -2 -> d.units[Math.floorMod(k + dir / 2, d.units.size)].first
                else -> i
            }
            c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("i$id", n).putInt("l$id", d.lv).apply()
        }

        private fun draw(c: Context, m: AppWidgetManager, id: Int) {
            val d = load(c)
            val views = if (d == null) {
                empty(c)
            } else if (Build.VERSION.SDK_INT >= 31) {
                // the launcher picks the layout that fits the widget's size; one picture of the hanzi for all three
                // (the same Bitmap is sent once)
                val b = hanzi(c, d.w[place(c, d, id)].h)
                RemoteViews(
                    mapOf(
                        SizeF(110f, 150f) to build(c, d, id, Shape.TALL, b),
                        SizeF(110f, 255f) to build(c, d, id, Shape.TALL_BIG, b),
                        SizeF(200f, 100f) to build(c, d, id, Shape.WIDE, b),
                    )
                )
            } else {
                val o = m.getAppWidgetOptions(id)
                val portrait = c.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
                val w = if (portrait) o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) else o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
                val h = if (portrait) o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) else o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
                val shape = when {
                    w >= 200 && w >= h * 1.3 -> Shape.WIDE
                    h >= 255 -> Shape.TALL_BIG
                    else -> Shape.TALL
                }
                build(c, d, id, shape, hanzi(c, d.w[place(c, d, id)].h))
            }
            try {
                m.updateAppWidget(id, views)
            } catch (_: Exception) {
            }
        }

        private enum class Shape { TALL, TALL_BIG, WIDE }

        private fun empty(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_word_tall)
            v.setImageViewBitmap(R.id.ww_han, hanzi(c, "学词"))
            v.setTextViewText(R.id.ww_head, c.getString(R.string.app_name))
            v.setTextViewText(R.id.ww_mean, c.getString(R.string.widget_empty))
            for (k in SYL.indices) v.setViewVisibility(SYL[k], View.GONE)
            for (x in listOf(R.id.ww_uprev, R.id.ww_unext, R.id.ww_prev, R.id.ww_next, R.id.ww_count, R.id.ww_line, R.id.ww_sent, R.id.ww_tr)) {
                v.setViewVisibility(x, View.GONE)
            }
            v.setOnClickPendingIntent(R.id.ww_root, open(c, null, 0))
            return v
        }

        private val SYL = intArrayOf(R.id.ww_s0, R.id.ww_s1, R.id.ww_s2, R.id.ww_s3, R.id.ww_s4, R.id.ww_s5)

        // the tone colours of the app (theme.dart): paper on the left, night on the right
        private val TONE_DAY = intArrayOf(0xFFB53127.toInt(), 0xFF8F5108.toInt(), 0xFF1A6B43.toInt(), 0xFF2A5CB4.toInt(), 0xFF6B665F.toInt())
        private val TONE_NIGHT = intArrayOf(0xFFFF8A76.toInt(), 0xFFF0B05A.toInt(), 0xFF6FD79B.toInt(), 0xFFA6C3FF.toInt(), 0xFFA9A3B4.toInt())

        private fun build(c: Context, d: Data, id: Int, shape: Shape, han: Bitmap): RemoteViews {
            val i = place(c, d, id)
            val w = d.w[i]
            val (start, size) = d.units[d.unitOf(i)]
            val v = RemoteViews(c.packageName, if (shape == Shape.WIDE) R.layout.widget_word_wide else R.layout.widget_word_tall)
            v.setImageViewBitmap(R.id.ww_han, han)
            v.setContentDescription(R.id.ww_han, "${w.h} ${w.syl.joinToString("")}")
            v.setTextViewText(
                R.id.ww_head,
                if (shape == Shape.WIDE) "HSK ${d.lv} · ${d.unit} ${w.u}".uppercase() else "HSK ${d.lv} · ${d.unitShort}${w.u}",
            )
            if (shape == Shape.WIDE) {
                v.setTextViewText(R.id.ww_seal, d.realm)
                v.setViewVisibility(R.id.ww_seal, if (d.realm.isEmpty()) View.GONE else View.VISIBLE)
            }
            // pinyin, one view per syllable so each keeps its tone colour (a 6th view takes the rest of a long word)
            val night = (c.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            for (k in SYL.indices) {
                if (k >= w.syl.size) {
                    v.setViewVisibility(SYL[k], View.GONE)
                    continue
                }
                val text = if (k == SYL.size - 1) w.syl.subList(k, w.syl.size).joinToString("") else w.syl[k]
                val t = (w.tones.getOrNull(k)?.digitToIntOrNull() ?: 5).coerceIn(1, 5) - 1
                v.setViewVisibility(SYL[k], View.VISIBLE)
                v.setTextViewText(SYL[k], text)
                if (Build.VERSION.SDK_INT >= 31) {
                    v.setColorInt(SYL[k], "setTextColor", TONE_DAY[t], TONE_NIGHT[t])
                } else {
                    v.setTextColor(SYL[k], if (night) TONE_NIGHT[t] else TONE_DAY[t])
                }
            }
            v.setTextViewText(R.id.ww_mean, w.m)
            v.setTextViewText(R.id.ww_count, "${i - start + 1} / $size")
            if (shape != Shape.WIDE) {
                val big = shape == Shape.TALL_BIG && w.z.isNotEmpty()
                for (x in listOf(R.id.ww_line, R.id.ww_sent, R.id.ww_tr)) v.setViewVisibility(x, if (big) View.VISIBLE else View.GONE)
                if (big) {
                    val s = SpannableString(w.z)
                    val at = w.z.indexOf(w.h)
                    if (at >= 0) {
                        s.setSpan(UnderlineSpan(), at, at + w.h.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        s.setSpan(StyleSpan(Typeface.BOLD), at, at + w.h.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                    v.setTextViewText(R.id.ww_sent, s)
                    v.setTextViewText(R.id.ww_tr, w.tr)
                    v.setViewVisibility(R.id.ww_tr, if (w.tr.isEmpty()) View.GONE else View.VISIBLE)
                }
            }
            // the buttons: request codes unique per widget and action
            v.setOnClickPendingIntent(R.id.ww_prev, stepIntent(c, id, -1))
            v.setOnClickPendingIntent(R.id.ww_next, stepIntent(c, id, 1))
            v.setOnClickPendingIntent(R.id.ww_uprev, stepIntent(c, id, -2))
            v.setOnClickPendingIntent(R.id.ww_unext, stepIntent(c, id, 2))
            v.setContentDescription(R.id.ww_uprev, d.labels[0])
            v.setContentDescription(R.id.ww_unext, d.labels[1])
            v.setContentDescription(R.id.ww_prev, d.labels[2])
            v.setContentDescription(R.id.ww_next, d.labels[3])
            v.setOnClickPendingIntent(R.id.ww_hanbox, open(c, "${d.lv}:${w.h}", id))
            return v
        }

        private fun stepIntent(c: Context, id: Int, dir: Int): PendingIntent {
            val i = Intent(c, XueciWordWidget::class.java).setAction(STEP)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id).putExtra("d", dir)
            val code = 100_000 + id * 8 + (dir + 2)
            return PendingIntent.getBroadcast(c, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        private fun open(c: Context, word: String?, id: Int): PendingIntent {
            val i = Intent(c, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (word != null) i.putExtra(EXTRA_WORD, word)
            return PendingIntent.getActivity(c, 200_000 + id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        /**
         * the hanzi in the app's serif (Noto Serif SC, from the app's own fonts), white on clear: the layout tints it
         * with the paper or night ink, so a change of the phone's dark mode needs no new picture
         */
        private fun hanzi(c: Context, h: String): Bitmap {
            val tf = serif ?: try {
                Typeface.createFromAsset(c.assets, "flutter_assets/assets/fonts/serif-sc-900.ttf")
            } catch (_: Exception) {
                Typeface.create(Typeface.SERIF, Typeface.BOLD)
            }.also { serif = it }
            val px = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, c.resources.displayMetrics)
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = tf
                if (!hasGlyph(h)) typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
                textSize = px
                color = Color.WHITE
                letterSpacing = 0.02f
            }
            val fm = p.fontMetrics
            val wpx = max(1, ceil(p.measureText(h)).toInt() + 4)
            val hpx = max(1, ceil(fm.descent - fm.ascent).toInt())
            val b = Bitmap.createBitmap(wpx, hpx, Bitmap.Config.ALPHA_8)
            Canvas(b).drawText(h, 2f, -fm.ascent, p)
            return b
        }
    }
}
