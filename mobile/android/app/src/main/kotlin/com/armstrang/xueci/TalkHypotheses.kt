package com.armstrang.xueci

/** Keeps a bounded set of complete alternatives when a BCT answer has several pieces. */
internal class TalkHypotheses {
    private data class Candidate(val text: String, val cost: Int)

    private var beam = listOf(Candidate("", 0))

    fun reset() {
        beam = listOf(Candidate("", 0))
    }

    fun add(raw: List<String>) {
        val choices = raw.asSequence().map(String::trim).filter(String::isNotEmpty).distinct().take(LIMIT).toList()
        if (choices.isEmpty()) return
        beam = beam.flatMap { prefix ->
            choices.mapIndexed { rank, choice ->
                Candidate(prefix.text + choice, prefix.cost + rank)
            }
        }.sortedBy { it.cost }.distinctBy { it.text }.take(LIMIT)
    }

    fun answers(): List<String> = beam.map { it.text }.filter { it.isNotEmpty() }

    private companion object {
        const val LIMIT = 5
    }
}
