#!/usr/bin/env python3
"""Generate paired training examples for BCT. Keep these families out of blind evaluation."""

from itertools import product
from pathlib import Path
import argparse
import json
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "content/talk/corpus"


def normalized(text):
    return re.sub(r"[^\w]", "", unicodedata.normalize("NFKC", text))


def frame(act, pol="+", **slots):
    return {"act": act, "pol": pol, **slots}


def rows():
    openings = ("我这边了解过，", "王经理，", "跟您说一声，", "这边核实过了，", "刚跟同事确认过，", "来跟您更新一下，")
    apologizes = ("真对不住。", "实在抱歉。", "让您久等了，真不好意思。", "给您添麻烦了，向您致歉。")
    causes = (
        ("海关还在查这批货。", "customs"), ("这批包装在运输途中受潮了。", "logistics"),
        ("出库系统短时间出了故障。", "other"), ("承运人原来的车临时坏了。", "logistics"),
        ("供应商漏发了一箱。", "other"), ("我们出库时贴错了标签。", "other"),
    )
    dispatches = (
        ("明早补寄出去", "tomorrow"), ("周四重新发", "thursday"),
        ("今天补发", "today"), ("后天重新寄出", "dayafter"),
    )
    arrivals = (
        ("周五上午能送到", "friday"), ("您星期六就能收到", "saturday"),
        ("周四傍晚到您仓库", "thursday"), ("周日才能交到您手上", "sunday"),
        ("礼拜五下班前送到", "friday"),
    )
    for opening, dispatch, arrival in product(openings, dispatches, arrivals):
        sent, sent_day = dispatch
        received, received_day = arrival
        yield "ship_and_arrive", f"{opening}我们{sent}，预计{received}。", [
            frame("resend", when=sent_day), frame("promise_time", when=received_day)
        ]
        yield "ship_without_arrival", f"{opening}我们{sent}，但到货时间还不能确定。", [
            frame("resend", when=sent_day)
        ]
        yield "quoted_eta", f"{opening}您刚才问能不能{received}，我还没有收到准确的到货时间。", []
        yield "eta_only", f"{opening}这票件{received}。", [frame("promise_time", when=received_day)]
    for apology, cause, arrival in product(apologizes, causes, arrivals):
        explanation, reason = cause
        received, received_day = arrival
        yield "mixed_acts", f"{apology}{explanation}我们这次{received}。", [
            frame("apologize"), frame("cause", reason=reason), frame("promise_time", when=received_day)
        ]
        yield "implicit_reassurance", f"{apology}{explanation}我有消息再联系您。", [
            frame("apologize"), frame("cause", reason=reason)
        ]
    unrelated = (
        "我昨天去学校接孩子", "食堂今天不开门", "他在说周末那场球赛", "我把咖啡放在桌上了",
        "上次那张照片是哪儿拍的", "楼下有人问这里有没有停车位", "我还没看完那部电影", "他看错了地铁的方向",
        "我朋友周四过生日", "早上的那堂课改到下周了", "你看到刚才那只猫了吗", "我今天才把图书馆的书还了",
    )
    for prefix, tail in product(("不好意思", "真对不住", "抱歉", "对不起", "实在不好意思", "真抱歉"), unrelated):
        yield "apology_with_unrelated_content", f"{prefix}，{tail}。", [frame("apologize")]
        yield "quoted_apology", f"他对朋友说{prefix}，因为{tail}。", []
    discounts = (("九五折", 5), ("九折", 10), ("八折", 20), ("减百分之十五", 15), ("少收一半", 50))
    for opening, discount in product(openings, discounts):
        phrase, pct = discount
        yield "discount_offer", f"{opening}我可以给您{phrase}。", [frame("discount", pct=pct)]
        yield "discount_refused", f"{opening}我们没法给您{phrase}。", [frame("discount", "-", pct=pct)]
        yield "discount_not_committed", f"{opening}{phrase}我只能去问，今天不能承诺。", []
        yield "alternative_compensation", f"{opening}不能给{phrase}，但是这次的运费我们来承担。", [
            frame("discount", "-", pct=pct), frame("compensate")
        ]
    for old, new in product(arrivals, arrivals):
        if old[1] == new[1]:
            continue
        for prefix in ("我更正一下，", "给您更新一下，", "刚重新确认过，", "最新的安排是，"):
            yield "corrected_arrival", f"{prefix}之前说{old[0]}已经不行了，这批货{new[0]}。", [
                frame("promise_time", when=new[1])
            ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--combined", type=Path, help="also write the training input for a candidate model")
    args = parser.parse_args()
    baseline = CORPUS / "train5_all.jsonl"
    # Holdout text is used only to reject exact accidental overlaps, never to generate utterances.
    reserved = [baseline, *CORPUS.glob("blind*.jsonl")]
    seen = {normalized(json.loads(line)["text"]) for path in reserved
            for line in path.read_text(encoding="utf-8").splitlines() if line.strip()}
    data = []
    for family, text, frames in rows():
        key = normalized(text)
        if key in seen:
            continue
        seen.add(key)
        data.append({"text": text, "frames": frames or [frame("none")], "tags": [family],
                     "set": "context_v5_train", "source": "constructed_pairs"})
    out = CORPUS / "context_v5_train.jsonl"
    out.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in data), encoding="utf-8")
    print(f"{len(data)} training lines in {out.name}")
    if args.combined:
        blind4 = CORPUS / "blind4_all.jsonl"
        excluded = {normalized(json.loads(line)["text"]) for line in blind4.read_text(encoding="utf-8").splitlines()
                    if line.strip()}
        paths = [baseline, out]
        lines = [line for path in paths for line in path.read_text(encoding="utf-8").splitlines()
                 if line.strip() and normalized(json.loads(line)["text"]) not in excluded]
        args.combined.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{len(lines)} lines after removing overlap with blind4")


if __name__ == "__main__":
    main()
