package com.armstrang.xueci

fun main() {
    val beam = TalkHypotheses()
    check(beam.answers().isEmpty())
    beam.add(listOf(" 您好 ", "", "您好", "您好呀"))
    check(beam.answers() == listOf("您好", "您好呀"))
    beam.add(listOf("周四送到", "周六送到", "以后送到"))
    val twoPieces = beam.answers()
    check(twoPieces.first() == "您好周四送到")
    check("您好呀周四送到" in twoPieces)
    check("您好周六送到" in twoPieces)
    beam.add(listOf("谢谢", "多谢"))
    val threePieces = beam.answers()
    check(threePieces.first() == "您好周四送到谢谢")
    check("您好呀周四送到谢谢" in threePieces)
    check("您好周六送到谢谢" in threePieces)
    check(threePieces.size <= 5 && threePieces.size == threePieces.distinct().size)
    repeat(30) { beam.add(listOf("好", "可", "是", "对", "行", "嗯")) }
    check(beam.answers().size <= 5)
    check(beam.answers().first().endsWith("好".repeat(30)))
    beam.reset()
    check(beam.answers().isEmpty())
    beam.add(emptyList())
    check(beam.answers().isEmpty())
    println("PASS early/later ASR alternatives, canonical first result, limit, deduplication, and reset")
}
