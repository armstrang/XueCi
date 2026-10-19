"""Add pinyin to every example sentence: field `zp` in content/vocab.json.

    python3 content/tools/sentence_pinyin.py PYPINYIN_DIR JIEBA_DIR

Needs two MIT-licensed libraries (pip install pypinyin jieba, or clones of
https://github.com/mozillazg/python-pinyin and https://github.com/fxsjy/jieba; pass the folders that contain the
`pypinyin` and `jieba` packages).

How a sentence is read:
  1. It is split into words: the app's words first (fewest pieces; ties go to the split that agrees with jieba's
     boundaries, then to the likelier words by jieba's counts), the word being learned is always kept whole.
     Sentences of HSK 1-6 only use the words of HSK 1-6, so advanced words (都会, 国有 ...) never split them;
     advanced sentences also use the advanced words that jieba itself finds in them. FIXED holds hand-read sentences.
  2. A word that is in the app's own list uses the app's pinyin, so it always agrees with the word cards
     (一/不 tone changes, neutral tones, erhua).
  3. Other characters are read by pypinyin over the whole sentence, so phrase context picks the reading of
     characters with several pronunciations (还给 huán, 长得 zhǎng, 有空 kòng ...), plus rules for what pypinyin
     leaves out: 一 and 不 tone changes, 是不是-type questions, 得/地 as particles, measure words 种/只,
     量体温 liáng, and erhua (儿 joins the syllable before it).
  4. Place names, languages and festivals are capitalised, and so are surnames before 老师/先生/...
Output: words separated by spaces, Western punctuation, capitalised sentences, the learned word in {...}
(the app shows it highlighted), e.g. "Wǒ {ài} wǒ de jiā."
"""
import json
import logging
import math
import os
import re
import sys
import warnings

warnings.filterwarnings('ignore', category=SyntaxWarning)
for p in sys.argv[1:3]:
    sys.path.insert(0, p)
import jieba  # noqa: E402
from pypinyin import Style, pinyin  # noqa: E402
from pypinyin.constants import PHRASES_DICT  # noqa: E402

jieba.setLogLevel(logging.WARNING)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VOCAB = os.path.join(ROOT, 'content', 'vocab.json')

PUNCT = {'，': ',', '。': '.', '？': '?', '！': '!', '：': ':', '；': ';', '、': ',', '“': '"', '”': '"', '‘': "'", '’': "'",
         '（': '(', '）': ')', '《': '«', '》': '»', '…': '…', '—': '—', '～': '~', '"': '"'}
TONE_MARKS = {1: 'āēīōūǖ', 2: 'áéíóúǘ', 3: 'ǎěǐǒǔǚ', 4: 'àèìòùǜ'}
NUM_BEFORE_YI = set('第十百千万零〇两几周')    # also 周一 (Monday)
DATE_AFTER_YI = set('月号日')
DI_NOUN_AFTER = set('上下里面方图铁区球址板毯点震位道')
PRONOUNS = set('我你他她它您咱')
DEMONS = set('这那哪一二三四五六七八九十两几每各某半')    # before a measure word
ER_WORDS = ('儿子', '女儿', '儿童', '婴儿', '幼儿', '孤儿', '儿科', '健儿', '儿女', '男儿', '少儿', '胎儿')
NOT_WORDS = ['花被', '个人']        # jieba entries that split common sentences wrongly (这种|花被, 每|个人)
PROPER = set('''汉语 中国 中文 普通话 英语 英文 法语 日语 韩语 德语 亚洲 非洲 欧洲 北美洲 南美洲 大洋洲 南极洲 中华 联合国
北京 上海 广州 深圳 天津 重庆 成都 西安 杭州 南京 武汉 香港 澳门 台湾 长城 长江 黄河 天安门 故宫 西湖 泰山
美国 英国 法国 德国 日本 韩国 泰国 越南 印度 印尼 俄罗斯 加拿大 澳大利亚 新加坡 马来西亚 意大利 西班牙 印度尼西亚
春节 中秋节 端午节 国庆节 元宵节 圣诞节 广东 广东话
四川 西藏 云南 内蒙古 湖南 苏州 桂林 黄山 景德镇 少林寺 青藏 珠穆朗玛峰 喜马拉雅 纽约 东南亚 北美洲
唐朝 唐代 秦始皇 李白 杜甫 诸葛亮 孔子 牛顿 奥运会 世界杯 清明节 红楼梦'''.split())
SURNAMES = set('王李张刘陈杨黄赵吴周徐孙马朱胡郭何高林罗郑梁谢宋唐许韩冯邓曹彭曾肖田董袁潘于蒋蔡余杜叶程苏魏吕丁任沈姚卢姜崔钟谭陆汪范金石廖贾夏韦付方白邹孟熊秦邱江尹薛闫段雷侯龙史陶黎贺顾毛郝龚邵万钱严覃武戴莫孔向汤')
# words that are not words before these characters
NOT_BEFORE = {'十分': '钟', '天下': '雨雪', '写作': '文'}
# sentences the rules read wrongly, written out by hand
FIXED = {'十八岁以上的人才能开车。': 'Shíbā suì {yǐshàng} de rén cáinéng kāichē.',
         '你留下来吃饭吧。': 'Nǐ {liú} xiàlai chīfàn ba.',
         '黄河流域是中华文明的发源地。': 'Huánghé liúyù shì Zhōnghuá wénmíng de {fāyuándì}.'}
TITLES = ('老师', '先生', '女士', '小姐', '经理', '医生', '大夫', '同学', '教授', '阿姨', '叔叔', '师傅', '主任', '校长')


def is_han(c):
    return '㐀' <= c <= '鿿' or c == '〇'


def tone(syl):
    for t, marks in TONE_MARKS.items():
        if any(m in syl for m in marks):
            return t
    return 5


def join_syllables(syls):
    """yī + ǎi -> yī'ǎi: apostrophe before a syllable that starts with a vowel."""
    out = ''
    for i, s in enumerate(syls):
        if i and s.lstrip('{')[:1].lower() in 'aeoāáǎàēéěèōóǒò':
            out += "'"
        out += s
    return out


def vocab_syllables(word, syls):
    """Pair each character with its syllable; an erhua 儿 has none (its r is already in the syllable before)."""
    out, j = [], 0
    for c in word:
        if c == '儿' and len(syls) < len(word) and out:
            out.append('')
        else:
            out.append(syls[j] if j < len(syls) else '')
            j += 1
    return out


ZI_FULL = {'电子', '原子', '分子', '因子', '粒子', '男子', '女子', '君子', '孔子', '弟子', '学子', '天子', '才子', '游子', '赤子'}
FUNCTION = set('很太都也还就才又再最更真的了着过吗呢吧啊在是有这那哪我你他她它们个一不没上下里中给把被和跟对从向')
MEASURES = set('个种只件本张条位次块双把辆杯瓶碗份家所座节门句篇台部首支棵朵片层间封匹头口顿场遍趟')
VERBS_BU_C = set('睡看听买找做说学吃喝走跑拿搬记想猜写读用穿洗修关打')
COMPLEMENTS = set('着见懂起到完了下动清会好开出来去住')


def segment(z, head, vocab):
    """Words: the app's own words (fewest pieces wins), names, the learned word kept whole; jieba only groups
    runs of characters the app doesn't know (蜡烛, 篮筐 ...)."""
    n = len(z)
    hs = z.find(head)
    he = hs + len(head) if hs >= 0 else -1
    known = {w for w in vocab if len(w) > 1} | PROPER

    def allowed(i, j):
        if hs >= 0 and i < he and j > hs and not (i <= hs and he <= j):
            return False                                   # may not cut through the learned word
        if z[j:j + 1] and z[j] in NOT_BEFORE.get(z[i:j], ''):
            return False                                   # 十|分钟, 天|下雨, 写|作文
        if z[i] in MEASURES and i and z[i - 1] in DEMONS and j - i > 1 and not (i == hs and j == he):
            return False                                   # 一|个|人, not 一|个人 (but 统一|口径 keeps the learned word)
        return True

    # ties are settled by agreeing with jieba's own word boundaries (早上|去, 加|工资, 十|分钟)
    jb, q = set(), 0
    for w in jieba.cut(z, HMM=False):
        q += len(w)
        jb.add(q)
    INF = (10 ** 9, 0, 0, 0)
    best = [INF] * (n + 1)
    back = [0] * (n + 1)
    best[n] = (0, 0, 0, 0)
    for i in range(n - 1, -1, -1):
        cands = [i + 1]
        for j in range(i + 2, min(n, i + 8) + 1):
            w = z[i:j]
            if (w in known or w == head) and allowed(i, j):
                cands.append(j)
        for j in cands:
            if j == i + 1 and not allowed(i, j) and hs <= i < he and he - hs > 1:
                continue
            # then the likelier words by jieba's counts (十|分钟, 加|工资, 老|师傅, 火车|站)
            cost = (best[j][0] + 1, best[j][1] - (j - i) ** 2, best[j][2] - (j in jb),
                    best[j][3] - math.log(jieba.dt.FREQ.get(z[i:j], 0) + 1))
            if cost < best[i]:
                best[i], back[i] = cost, j
    spans, i = [], 0
    while i < n:
        j = back[i] if back[i] > i else i + 1          # never stall (a position no word may start from)
        spans.append((i, j))
        i = j
    # group single characters into words the app doesn't list (蜡烛, 草药, 发型 ...): jieba for characters the app
    # doesn't know at all, and two-character words found in both jieba's and pypinyin's dictionaries otherwise
    single_known = {w for w in vocab if len(w) == 1}
    out, k = [], 0
    while k < len(spans):
        a, b = spans[k]
        if b - a == 1 and is_han(z[a]) and not (hs <= a < he):
            m = k
            while m + 1 < len(spans) and spans[m + 1][1] - spans[m + 1][0] == 1 and is_han(z[spans[m + 1][0]]) \
                    and not (hs <= spans[m + 1][0] < he):
                m += 1
            run_a, run_b = spans[k][0], spans[m][1]
            pos = run_a
            while pos < run_b:
                two = z[pos:pos + 2]
                freq = jieba.dt.FREQ.get(two, 0)
                if (len(two) == 2 and pos + 2 <= run_b and freq > 0 and (two in PHRASES_DICT or freq >= 100)
                        and not (set(two) & FUNCTION) and z[pos] not in DEMONS
                        and not (z[pos] in MEASURES and pos and z[pos - 1] in DEMONS)):
                    out.append((pos, pos + 2))
                    pos += 2
                    continue
                if z[pos] not in single_known:
                    end = pos
                    while end < run_b and z[end] not in single_known:
                        end += 1
                    q = pos
                    for w in jieba.cut(z[pos:end], HMM=False):
                        out.append((q, q + len(w)))
                        q += len(w)
                    pos = end
                    continue
                out.append((pos, pos + 1))
                pos += 1
            k = m + 1
            continue
        out.append((a, b))
        k += 1
    return out


def read_sentence(z, head, vocab):
    ctx = [p[0] for p in pinyin(z, style=Style.TONE, errors=lambda chars: list(chars))]
    if len(ctx) != len(z):
        ctx = [pinyin(c, style=Style.TONE, errors=lambda ch: [ch])[0][0] for c in z]
    hs = z.find(head)
    he = hs + len(head) if hs >= 0 else -1
    spans = segment(z, head, vocab)
    syl = list(ctx)                   # one syllable per character ('' for a merged 儿)
    fixed = [False] * len(z)          # readings that come from the app's word list
    for a, b in spans:
        w = z[a:b]
        if w in vocab and (b - a > 1 or a == hs):   # single characters are read in context (长, 着, 一 ...)
            syl[a:b] = vocab_syllables(w, vocab[w])
            fixed[a:b] = [True] * (b - a)
    tok_of = {}
    for k, (a, b) in enumerate(spans):
        for i in range(a, b):
            tok_of[i] = k

    def next_tone(i):
        j = i + 1
        while j < len(z) and syl[j] == '' and is_han(z[j]):
            j += 1
        return tone(syl[j]) if j < len(z) and is_han(z[j]) else None

    for i, c in enumerate(z):
        if fixed[i] or not is_han(c):
            continue
        a, b = spans[tok_of[i]]
        before, after = z[i - 1] if i else '', z[i + 1] if i + 1 < len(z) else ''
        single = b - a == 1
        if c == '的' and single:
            syl[i] = 'de'                                             # 项目|的, never 目的 dì across words
        elif c == '一':
            if not after or not is_han(after) or before in NUM_BEFORE_YI or after in DATE_AFTER_YI or after == '一':
                syl[i] = 'yī'
            else:
                syl[i] = 'yí' if next_tone(i) in (4, 5) else 'yì'
        elif c == '不':
            if before and before == after and is_han(before):
                syl[i] = 'bu'                                         # 是不是, 好不好
            elif before in VERBS_BU_C and after in COMPLEMENTS:
                syl[i] = 'bu'                                         # 睡不着, 听不懂
            else:
                syl[i] = 'bú' if next_tone(i) == 4 else 'bù'
        elif c == '地' and i and after and is_han(after) and after not in DI_NOUN_AFTER:
            pa, pb = spans[tok_of[i - 1]]
            if (pb - pa >= 2 and fixed[i - 1]) or (i >= 2 and z[i - 1] == z[i - 2]):
                syl[i] = 'de'                                         # 高兴地笑, 慢慢地走
        elif c == '得':
            syl[i] = 'děi' if before in PRONOUNS and after and is_han(after) and after not in '很太不更' else 'de'
        elif c == '着':
            if after in '急火凉迷' or z[max(0, i - 2):i] in ('睡不', '找不', '猜不', '摸不') or before in '睡':
                syl[i] = 'zháo'
            else:
                syl[i] = 'zhe'
        elif c == '种' and before in DEMONS:
            syl[i] = 'zhǒng'
        elif c == '只' and before in DEMONS and after not in '是有能要好':
            syl[i] = 'zhī'
        elif c == '量' and (z[i + 1:i + 3] == '一下' or any(t in z[i + 1:i + 7] for t in ('体温', '身高', '血压', '体重', '尺寸'))):
            syl[i] = 'liáng'
        elif c == '场' and before in DEMONS:
            syl[i] = 'cháng' if after in '雨雪病风梦大' else 'chǎng'      # 一场雨 cháng, 一场比赛 chǎng
        elif c == '子' and z[i - 1:i + 1] in ZI_FULL:
            syl[i] = 'zǐ'                                             # 电子 diànzǐ (not the neutral -zi of 桌子)
        elif c == '长':
            syl[i] = 'zhǎng' if after and after in '大得高' else 'cháng'
        elif c == '儿' and z[a:b] not in ER_WORDS and i and syl[i - 1] and is_han(z[i - 1]):
            syl[i - 1] += 'r'                                         # erhua: 儿 joins the syllable before
            syl[i] = ''

    # words; 们 joins the word before
    words = []                        # [text, kind]
    for a, b in spans:
        w = z[a:b]
        if not is_han(w[0]):
            for j, ch in enumerate(w):
                if ch in PUNCT:
                    words.append([PUNCT[ch], 'p'])
                elif not ch.isspace():
                    if words and words[-1][1] == 'x':
                        words[-1][0] += ch
                    else:
                        words.append([ch, 'x'])
            continue
        parts = []
        for i in range(a, b):
            if not syl[i]:
                continue
            s = syl[i]
            if hs <= i < he:
                if i == hs:
                    s = '{' + s
                if all(not syl[k] for k in range(i + 1, he)):
                    s = s + '}'
            parts.append(s)
        if not parts:                 # a lone erhua 儿 already joined the word before
            continue
        text = join_syllables(parts)
        if w in PROPER or (b - a == 1 and w in SURNAMES and z[b:].startswith(TITLES)):
            k = 1 if text.startswith('{') else 0
            text = text[:k] + text[k:k + 1].upper() + text[k + 1:]
        if w == '们' and words and words[-1][1] == 'w':
            words[-1][0] += text
            continue
        words.append([text, 'w'])
    # the r of a lone erhua went onto the previous syllable: refresh words that end before a merged 儿
    # (handled above by editing syl before the words were built)

    # spacing and punctuation; straight quotes open and close in turn
    s, quote_open = '', False
    for text, kind in words:
        if kind == 'p':
            opening = text in '(«' or (text in '"\'' and not quote_open)
            if text in '"\'':
                quote_open = not quote_open
            if opening:
                s = (s.rstrip() + ' ' if s.strip() else '') + text
            else:
                s = s.rstrip() + text + ' '
            continue
        if s and not s.endswith((' ', '"', '(', '«', "'")):
            s += ' '
        s += text + ' '
    s = ' '.join(s.split())
    # capital letter at the start of every sentence and of quoted speech
    s = re.sub(r'(^["«]?|[.?!]["»]?\s+["«]?|:\s*["«])(\{?)([a-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü])',
               lambda m: m.group(1) + m.group(2) + m.group(3).upper(), s)
    return s


def main():
    with open(VOCAB, encoding='utf8') as f:
        data = json.load(f)
    # Levels 1-6 are read with the words of levels 1-6 only, so the advanced words (都会 metropolis, 国有, 作对 ...)
    # never split an everyday sentence wrongly (我都会 = dōu huì, 中国有 = Zhōngguó yǒu).
    vocab = {d['h']: d['s'] for d in data if d['l'] <= 6}
    jieba.initialize()
    for w in NOT_WORDS:
        jieba.del_word(w)
    for w in vocab:                   # make sure jieba knows the app's words (without pushing them over common splits)
        if len(w) > 1 and w not in jieba.dt.FREQ and w not in NOT_WORDS:
            jieba.add_word(w)
    advanced = {d['h']: d['s'] for d in data if d['l'] > 6}
    for d in data:
        if d['z'] in FIXED:
            d['zp'] = FIXED[d['z']]
            continue
        if d['l'] <= 6:
            d['zp'] = read_sentence(d['z'], d['h'], vocab)
            continue
        # an advanced sentence also uses the advanced words that jieba itself cuts out of it, and its own word
        cut = set(jieba.cut(d['z'], HMM=False))
        v = dict(vocab)
        v.update({w: s for w, s in advanced.items() if w == d['h'] or (len(w) > 1 and w in cut)})
        d['zp'] = read_sentence(d['z'], d['h'], v)
    with open(VOCAB, 'w', encoding='utf8') as f:
        f.write('[\n' + ',\n'.join(json.dumps(x, ensure_ascii=False, separators=(',', ':')) for x in data) + '\n]\n')
    print(f'{len(data)} sentences')


if __name__ == '__main__':
    main()
