"""Add word frequency and part of speech to web/data/vocab.json (fields f and g).

    python3 web/tools/word_freq.py JIEBA_DIR

JIEBA_DIR is a checkout of https://github.com/fxsjy/jieba (MIT licence, the same library sentence_pinyin.py uses);
its dictionary jieba/dict.txt lists about 350,000 words with a corpus count and a part-of-speech tag.

  f  Zipf frequency: log10 of the word's frequency per billion words, one decimal (about 2 = rare, 7 = very common).
     Words the dictionary doesn't have get their level's average.
  g  jieba part-of-speech tag (n noun, v verb, a adjective, d adverb, m numeral, q measure word, ...; '' if unknown).

The learning engine uses f for a word's difficulty within its HSK level (placement test, order of new words, first
memory estimate) and g to pick sentence-gap options of the same word class.
"""
import json
import math
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VOCAB = os.path.join(ROOT, 'web', 'data', 'vocab.json')


def main(jieba_dir):
    counts, tags, total = {}, {}, 0
    with open(os.path.join(jieba_dir, 'jieba', 'dict.txt'), encoding='utf8') as f:
        for line in f:
            p = line.split()
            if len(p) < 2:
                continue
            counts[p[0]] = int(p[1])
            tags[p[0]] = p[2] if len(p) > 2 else ''
            total += int(p[1])
    with open(VOCAB, encoding='utf8') as f:
        data = json.load(f)
    zipf = lambda c: math.log10(c / total * 1e9)
    mean = {l: statistics.mean(zipf(counts[d['h']]) for d in data if d['l'] == l and d['h'] in counts) for l in range(1, 7)}
    for d in data:
        c = counts.get(d['h'])
        d['f'] = round(zipf(c) if c else mean[d['l']], 1)
        d['g'] = tags.get(d['h'], '')
    with open(VOCAB, 'w', encoding='utf8') as f:
        f.write('[\n' + ',\n'.join(json.dumps(x, ensure_ascii=False, separators=(',', ':')) for x in data) + '\n]\n')
    print(f'{len(data)} words; {sum(1 for d in data if d["h"] not in counts)} not in the dictionary')


if __name__ == '__main__':
    main(sys.argv[1])
