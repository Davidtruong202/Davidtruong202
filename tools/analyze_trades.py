#!/usr/bin/env python3
"""Phân tích log do EA TradeLogger.mq5 xuất ra để ước lượng cách vào lệnh.

Cách dùng:
    pip install pandas numpy scikit-learn
    python tools/analyze_trades.py --dir "<đường dẫn MQL5/Files>" --out report.md

Script đọc:
    <prefix>_deals.csv    (bắt buộc)  từng deal + đặc trưng thị trường lúc khớp
    <prefix>_bars_*.csv   (nên có)    mọi nến + đặc trưng -> so sánh vào lệnh vs không
    <prefix>_orders.csv   (tuỳ chọn)  loại lệnh (market / limit / stop)
    <prefix>_events.csv   (tuỳ chọn)  sửa SL/TP khi đang giữ lệnh
    <prefix>_symbols.csv  (tuỳ chọn)  point/digits để quy ra point
"""
from __future__ import annotations

import argparse
import glob
import os
import sys

import numpy as np
import pandas as pd

try:
    from sklearn.metrics import roc_auc_score
    from sklearn.tree import DecisionTreeClassifier, export_text
    HAVE_SKLEARN = True
except ImportError:  # vẫn chạy phần thống kê nếu thiếu sklearn
    HAVE_SKLEARN = False

FEATURE_LABELS = {
    "f_hour": "giờ (server)",
    "f_weekday": "thứ (0=CN)",
    "f_body_atr": "thân nến/ATR (+tăng, -giảm)",
    "f_range_atr": "biên độ nến/ATR",
    "f_upwick_atr": "râu trên/ATR",
    "f_lowwick_atr": "râu dưới/ATR",
    "f_streak": "số nến cùng màu liên tiếp (+xanh, -đỏ)",
    "f_rsi": "RSI(14)",
    "f_dist_ema20_atr": "giá - EMA20 (ATR)",
    "f_dist_ema50_atr": "giá - EMA50 (ATR)",
    "f_dist_ema200_atr": "giá - EMA200 (ATR)",
    "f_ema20_slope_atr": "độ dốc EMA20",
    "f_ema50_slope_atr": "độ dốc EMA50",
    "f_ema_stack": "xếp EMA (+1 tăng, -1 giảm)",
    "f_bb_pctb": "Bollinger %B (0=dải dưới, 1=dải trên)",
    "f_bb_width_atr": "độ rộng Bollinger/ATR",
    "f_macd_hist_atr": "MACD histogram/ATR",
    "f_macd_main_atr": "MACD main/ATR",
    "f_stoch_k": "Stochastic %K",
    "f_stoch_d": "Stochastic %D",
    "f_dist_hh20_atr": "khoảng cách tới đỉnh 20 nến (ATR)",
    "f_dist_ll20_atr": "khoảng cách tới đáy 20 nến (ATR)",
    "f_break_hh20": "phá đỉnh 20 nến",
    "f_break_ll20": "phá đáy 20 nến",
    "f_dist_pdh_atr": "giá - đỉnh hôm qua (ATR)",
    "f_dist_pdl_atr": "giá - đáy hôm qua (ATR)",
    "f_dist_dopen_atr": "giá - giá mở cửa ngày (ATR)",
    "f_pos_day_range": "vị trí trong biên độ ngày (0=đáy, 1=đỉnh)",
    "f_dist_today_hi_atr": "khoảng cách tới đỉnh hôm nay (ATR)",
    "f_dist_today_lo_atr": "khoảng cách tới đáy hôm nay (ATR)",
    "f_bias_rsi": "RSI khung lớn",
    "f_bias_dist_ema50_atr": "giá - EMA50 khung lớn (ATR)",
    "f_bias_dist_ema200_atr": "giá - EMA200 khung lớn (ATR)",
    "f_bias_ema50_slope_atr": "độ dốc EMA50 khung lớn",
}
MODEL_FEATURES = list(FEATURE_LABELS)
WEEKDAYS = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]


def label(f: str) -> str:
    return f"{f} ({FEATURE_LABELS[f]})" if f in FEATURE_LABELS else f


class Report:
    def __init__(self) -> None:
        self.lines: list[str] = []

    def h(self, text: str, level: int = 2) -> None:
        self.lines += ["", "#" * level + " " + text, ""]

    def p(self, text: str = "") -> None:
        self.lines.append(text)

    def table(self, df: pd.DataFrame, floatfmt: str = "{:.3g}") -> None:
        cols = [str(c) for c in df.columns]
        self.lines.append("| " + " | ".join(cols) + " |")
        self.lines.append("|" + "---|" * len(cols))
        for _, row in df.iterrows():
            cells = []
            for v in row.values:
                if isinstance(v, (float, np.floating)):
                    cells.append("" if np.isnan(v) else floatfmt.format(v))
                else:
                    cells.append(str(v))
            self.lines.append("| " + " | ".join(cells) + " |")
        self.lines.append("")

    def code(self, text: str) -> None:
        self.lines += ["```", text.rstrip(), "```", ""]

    def text(self) -> str:
        return "\n".join(self.lines).strip() + "\n"


# ---------------------------------------------------------------------------
# Đọc dữ liệu
# ---------------------------------------------------------------------------
def read_csv(path: str) -> pd.DataFrame:
    for enc in ("utf-8", "utf-16", "cp1252"):
        try:
            return pd.read_csv(path, encoding=enc)
        except UnicodeError:
            continue
    return pd.read_csv(path, encoding="latin-1")


def parse_time(s: pd.Series) -> pd.Series:
    return pd.to_datetime(s, format="%Y.%m.%d %H:%M:%S", errors="coerce")


def load(dirpath: str, prefix: str):
    deals_path = os.path.join(dirpath, f"{prefix}_deals.csv")
    if not os.path.exists(deals_path):
        sys.exit(f"Không tìm thấy {deals_path}")
    deals = read_csv(deals_path)
    deals["time"] = parse_time(deals["time"])
    deals["feat_bar_time"] = parse_time(deals["feat_bar_time"])
    deals = deals.sort_values(["time_msc", "deal_ticket"]).reset_index(drop=True)

    bars = {}
    for path in sorted(glob.glob(os.path.join(dirpath, f"{prefix}_bars_*.csv"))):
        b = read_csv(path)
        if b.empty:
            continue
        b["feat_bar_time"] = parse_time(b["feat_bar_time"])
        bars[str(b["symbol"].iloc[0])] = b.sort_values("feat_bar_time").reset_index(drop=True)

    def optional(name):
        p = os.path.join(dirpath, f"{prefix}_{name}.csv")
        return read_csv(p) if os.path.exists(p) else None

    return deals, bars, optional("orders"), optional("events"), optional("symbols")


def build_positions(deals: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for pid, g in deals.groupby("position_id", sort=False):
        ins = g[g["entry"].isin(["IN", "INOUT"])]
        outs = g[g["entry"].isin(["OUT", "OUT_BY", "INOUT"])]
        if ins.empty:
            continue
        first = ins.iloc[0]
        direction = 1 if first["type"] == "BUY" else -1
        vol_in = ins["volume"].sum()
        row = {
            "position_id": pid,
            "symbol": first["symbol"],
            "dir": direction,
            "open_time": first["time"],
            "open_price": (ins["price"] * ins["volume"]).sum() / vol_in,
            "volume": vol_in,
            "sl": first["sl"],
            "tp": first["tp"],
            "magic": first["magic"],
            "entry_reason": first["reason"],
            "comment": first["comment"],
            "closed": not outs.empty,
            "close_time": outs["time"].iloc[-1] if not outs.empty else pd.NaT,
            "close_price": (outs["price"] * outs["volume"]).sum() / outs["volume"].sum() if not outs.empty else np.nan,
            "exit_reason": outs["reason"].iloc[-1] if not outs.empty else "",
            "n_exits": len(outs),
            "net": g[["profit", "commission", "swap", "fee"]].sum().sum(),
        }
        for f in ["feat_bar_time"] + MODEL_FEATURES + ["f_atr", "f_close"]:
            row[f] = first.get(f, np.nan)
        rows.append(row)
    pos = pd.DataFrame(rows)
    if pos.empty:
        return pos
    pos = pos.sort_values("open_time").reset_index(drop=True)
    pos["hold_min"] = (pos["close_time"] - pos["open_time"]).dt.total_seconds() / 60
    pos["sl_dist"] = np.where(pos["sl"] > 0, (pos["open_price"] - pos["sl"]).abs(), np.nan)
    pos["tp_dist"] = np.where(pos["tp"] > 0, (pos["tp"] - pos["open_price"]).abs(), np.nan)
    pos["sl_atr"] = pos["sl_dist"] / pos["f_atr"]
    pos["tp_atr"] = pos["tp_dist"] / pos["f_atr"]
    pos["rr"] = pos["tp_dist"] / pos["sl_dist"]
    pos["move"] = (pos["close_price"] - pos["open_price"]) * pos["dir"]
    return pos


# ---------------------------------------------------------------------------
# Hồ sơ chiến lược
# ---------------------------------------------------------------------------
def max_streak(mask: pd.Series) -> int:
    best = cur = 0
    for v in mask:
        cur = cur + 1 if v else 0
        best = max(best, cur)
    return best


def profile(pos: pd.DataFrame, orders, events, symbols, rep: Report) -> list[str]:
    """Trả về danh sách nhận định ngắn để đưa lên đầu báo cáo."""
    notes: list[str] = []
    closed = pos[pos["closed"]]
    points = {}
    if symbols is not None:
        points = dict(zip(symbols["symbol"], symbols["point"]))

    rep.h("1. Tổng quan")
    days = max((pos["open_time"].max() - pos["open_time"].min()).days, 1)
    wins = closed["net"] > 0
    gross_win = closed.loc[wins, "net"].sum()
    gross_loss = -closed.loc[~wins, "net"].sum()
    equity = closed.sort_values("close_time")["net"].cumsum()
    dd = (equity.cummax().clip(lower=0) - equity).max() if len(equity) else 0
    summary = pd.DataFrame([
        ("Số lệnh (position)", len(pos)),
        ("Đã đóng", len(closed)),
        ("Symbol", ", ".join(pos["symbol"].value_counts().index)),
        ("Khoảng thời gian", f"{pos['open_time'].min()} → {pos['open_time'].max()} ({days} ngày)"),
        ("Lệnh / ngày", f"{len(pos) / days:.2f}"),
        ("Lợi nhuận ròng", f"{closed['net'].sum():.2f}"),
        ("Tỉ lệ thắng", f"{wins.mean() * 100:.1f}%" if len(closed) else "-"),
        ("Profit factor", f"{gross_win / gross_loss:.2f}" if gross_loss > 0 else "∞"),
        ("TB lệnh thắng / thua", f"{closed.loc[wins, 'net'].mean():.2f} / {closed.loc[~wins, 'net'].mean():.2f}"),
        ("Thua liên tiếp tối đa", max_streak(~wins)),
        ("Sụt giảm tối đa (trên lệnh đã đóng)", f"{dd:.2f}"),
        ("Thời gian giữ lệnh (trung vị)", f"{closed['hold_min'].median():.1f} phút"),
    ], columns=["Chỉ số", "Giá trị"])
    rep.table(summary)

    # Bot hay tay
    auto = (pos["magic"] != 0) | pos["entry_reason"].astype(str).str.contains("EXPERT")
    rep.h("2. Bot (EA) hay đánh tay?")
    rep.table(pos["entry_reason"].value_counts().rename_axis("Nguồn vào lệnh").reset_index(name="Số lệnh"))
    if auto.mean() > 0.8:
        notes.append(f"{auto.mean() * 100:.0f}% lệnh do **EA** đặt (magic/DEAL_REASON_EXPERT) → quy tắc máy móc, "
                     "khả năng suy ra được là cao.")
        mg = pos.loc[auto, "magic"].value_counts()
        rep.p(f"Magic number: {', '.join(f'{m} ({c} lệnh)' for m, c in mg.items())}")
        cm = pos["comment"].dropna().astype(str).value_counts().head(5)
        if len(cm):
            rep.p("Comment phổ biến (thường lộ tên EA/setup): " + ", ".join(f"`{c}` ({n})" for c, n in cm.items()))
    elif auto.mean() < 0.2:
        notes.append("Phần lớn lệnh **đánh tay** (client/mobile/web) → có thể có yếu tố cảm tính, "
                     "mô hình chỉ ước lượng được một phần.")
    else:
        notes.append(f"Kết hợp: {auto.mean() * 100:.0f}% lệnh từ EA, còn lại đánh tay.")

    # Thời gian
    rep.h("3. Thời điểm vào lệnh (giờ server)")
    hours = pos["open_time"].dt.hour.value_counts().sort_index()
    rep.table(pd.DataFrame({"Giờ": hours.index, "Số lệnh": hours.values,
                            "%": (hours.values / len(pos) * 100).round(1)}))
    top = hours.sort_values(ascending=False)
    cum = top.cumsum() / len(pos)
    k = int((cum < 0.8).sum()) + 1
    if k <= 6:
        notes.append(f"80% lệnh tập trung trong {k} khung giờ: {sorted(top.index[:k].tolist())} (giờ server).")
    wd = pos["open_time"].dt.dayofweek.map(lambda d: WEEKDAYS[(d + 1) % 7]).value_counts()
    rep.p("Theo thứ: " + ", ".join(f"{d}: {n}" for d, n in wd.items()))

    # Hướng
    rep.h("4. Hướng lệnh")
    by_sym = pos.groupby("symbol")["dir"].agg(buy=lambda s: (s > 0).sum(), sell=lambda s: (s < 0).sum())
    rep.table(by_sym.reset_index())

    # SL / TP
    rep.h("5. Stop loss / Take profit")
    sl_use = (pos["sl"] > 0).mean()
    tp_use = (pos["tp"] > 0).mean()
    rep.p(f"Đặt SL ngay khi vào: {sl_use * 100:.0f}% lệnh · đặt TP: {tp_use * 100:.0f}% lệnh")
    rows = []
    for sym, g in pos.groupby("symbol"):
        pt = points.get(sym, np.nan)
        for name, col, atrcol in [("SL", "sl_dist", "sl_atr"), ("TP", "tp_dist", "tp_atr")]:
            d = g[col].dropna()
            if d.empty:
                continue
            rows.append({"Symbol": sym, "Loại": name,
                         "Trung vị (giá)": d.median(),
                         "Trung vị (point)": d.median() / pt if pt == pt else np.nan,
                         "Hệ số biến thiên": d.std() / d.mean() if len(d) > 1 else 0,
                         "Trung vị (xATR)": g[atrcol].median(),
                         "HSBT theo ATR": g[atrcol].std() / g[atrcol].mean() if len(d) > 1 else 0})
    if rows:
        t = pd.DataFrame(rows)
        rep.table(t)
        for _, r in t.iterrows():
            if r["Hệ số biến thiên"] < 0.1:
                notes.append(f"{r['Symbol']}: {r['Loại']} **cố định** ≈ {r['Trung vị (point)']:.0f} point.")
            elif r["HSBT theo ATR"] < 0.2 and r["HSBT theo ATR"] < r["Hệ số biến thiên"] / 2:
                notes.append(f"{r['Symbol']}: {r['Loại']} theo ATR ≈ {r['Trung vị (xATR)']:.2f} × ATR.")
    if sl_use < 0.2:
        notes.append("Hầu như **không đặt SL** khi vào lệnh → rủi ro cao (thường gặp ở grid/martingale).")
    rr = pos["rr"].dropna()
    if len(rr):
        rep.p(f"R:R dự kiến (TP/SL) trung vị: {rr.median():.2f}")

    rep.p()
    er = closed["exit_reason"].value_counts()
    rep.p("Cách đóng lệnh: " + ", ".join(f"{r}: {n}" for r, n in er.items()))
    same_sec = closed.groupby(["symbol", "close_time"]).size()
    basket = (same_sec[same_sec > 1].sum() / len(closed)) if len(closed) else 0
    if basket > 0.3:
        notes.append(f"{basket * 100:.0f}% lệnh được đóng **cùng lúc theo rổ** → dấu hiệu grid/đóng theo tổng lợi nhuận.")

    # Martingale / grid
    rep.h("6. Quản lý khối lượng: martingale / grid / nhồi lệnh")
    ps = closed.sort_values("close_time")
    after_loss, after_win = [], []
    for sym, g in pos.groupby("symbol"):
        g = g.sort_values("open_time")
        for i in range(1, len(g)):
            prev_closed = ps[(ps["symbol"] == sym) & (ps["close_time"] <= g["open_time"].iloc[i])]
            if prev_closed.empty:
                continue
            ratio = g["volume"].iloc[i] / prev_closed["volume"].iloc[-1]
            (after_loss if prev_closed["net"].iloc[-1] < 0 else after_win).append(ratio)
    if after_loss:
        ml = np.median(after_loss)
        mw = np.median(after_win) if after_win else np.nan
        rep.p(f"Tỉ lệ lot lệnh sau / lệnh trước: sau lệnh thua = {ml:.2f}, sau lệnh thắng = {mw:.2f}")
        if ml >= 1.3:
            notes.append(f"**Martingale**: sau lệnh thua lot tăng ×{ml:.2f} (trung vị).")
    vol_cv = pos["volume"].std() / pos["volume"].mean() if len(pos) > 1 else 0
    rep.p(f"Lot: min {pos['volume'].min()}, trung vị {pos['volume'].median()}, max {pos['volume'].max()} "
          f"(hệ số biến thiên {vol_cv:.2f})")
    if vol_cv < 0.05:
        notes.append(f"Lot **cố định** {pos['volume'].median()}.")

    stacked, spacing, against = 0, [], 0
    for sym, g in pos.groupby("symbol"):
        g = g.sort_values("open_time").reset_index(drop=True)
        for i in range(len(g)):
            t, d = g.loc[i, "open_time"], g.loc[i, "dir"]
            prior = g.iloc[:i]
            open_same = prior[(prior["dir"] == d) & ((prior["close_time"] > t) | prior["close_time"].isna())]
            if len(open_same):
                stacked += 1
                last = open_same.iloc[-1]
                gap = (g.loc[i, "open_price"] - last["open_price"]) * d
                if g.loc[i, "f_atr"] == g.loc[i, "f_atr"] and g.loc[i, "f_atr"] > 0:
                    spacing.append(abs(gap) / g.loc[i, "f_atr"])
                if gap < 0:
                    against += 1
    if len(pos):
        rep.p(f"Lệnh mở thêm khi đang có lệnh cùng chiều: {stacked}/{len(pos)} ({stacked / len(pos) * 100:.0f}%)")
    if stacked / max(len(pos), 1) > 0.3:
        kind = "nhồi lệnh khi giá đi ngược (**grid/DCA**)" if against > stacked / 2 else "nhồi lệnh thuận xu hướng (**pyramiding**)"
        extra = f", khoảng cách trung vị {np.median(spacing):.2f} × ATR" if spacing else ""
        notes.append(f"{stacked / len(pos) * 100:.0f}% lệnh là {kind}{extra}.")

    # Loại lệnh
    if orders is not None and not orders.empty:
        rep.h("7. Loại lệnh (market hay lệnh chờ)")
        vc = orders["type"].value_counts()
        rep.table(vc.rename_axis("Loại").reset_index(name="Số lượng"))
        pending = vc[vc.index.str.contains("LIMIT|STOP", regex=True) & ~vc.index.str.contains("STOP_LIMIT_NONE")].sum()
        if pending / vc.sum() > 0.3:
            notes.append(f"{pending / vc.sum() * 100:.0f}% order là **lệnh chờ** (limit/stop) → vào lệnh theo mức giá định trước.")

    # Quản lý lệnh
    if events is not None and not events.empty:
        rep.h("8. Quản lý lệnh khi đang giữ (từ log thời gian thực)")
        mods = events[(events["kind"] == "POSITION") & (events["event"] == "MODIFY")]
        rep.p(f"Số lần sửa SL/TP/khối lượng: {len(mods)} trên {events[events['kind'] == 'POSITION']['ticket'].nunique()} vị thế theo dõi được.")
        if len(mods):
            be = 0
            for _, m in mods.iterrows():
                if m["sl"] > 0 and abs(m["sl"] - m["price"]) <= 1e-9 * max(m["price"], 1) * 1000:
                    be += 1
            rep.p(f"Trong đó dời SL về giá vào (hoà vốn): {be}")
            if len(mods) > 0.5 * events[events['kind'] == 'POSITION']['ticket'].nunique():
                notes.append("Thường xuyên sửa SL khi đang giữ lệnh → có **trailing stop / dời hoà vốn**.")
    return notes


# ---------------------------------------------------------------------------
# Tìm quy tắc vào lệnh
# ---------------------------------------------------------------------------
def effect_table(entries: pd.DataFrame, base: pd.DataFrame, feats: list[str]) -> pd.DataFrame:
    rows = []
    for f in feats:
        a, b = entries[f].dropna(), base[f].dropna()
        if len(a) < 5 or len(b) < 5 or b.std() == 0:
            continue
        rows.append({"Đặc trưng": label(f), "TB lúc vào lệnh": a.mean(), "TB mọi nến": b.mean(),
                     "Độ lệch (σ)": (a.mean() - b.mean()) / b.std(), "_f": f})
    t = pd.DataFrame(rows)
    if t.empty:
        return t
    return t.reindex(t["Độ lệch (σ)"].abs().sort_values(ascending=False).index)


def fit_tree(X: pd.DataFrame, y: np.ndarray, depth: int, min_leaf: int):
    n = len(X)
    cut = int(n * 0.7)
    Xtr, Xte, ytr, yte = X.iloc[:cut], X.iloc[cut:], y[:cut], y[cut:]
    clf = DecisionTreeClassifier(max_depth=depth, min_samples_leaf=min_leaf, class_weight="balanced", random_state=0)
    clf.fit(Xtr, ytr)
    auc = np.nan
    if len(np.unique(yte)) == 2:
        auc = roc_auc_score(yte, clf.predict_proba(Xte)[:, 1])
    full = DecisionTreeClassifier(max_depth=depth, min_samples_leaf=min_leaf, class_weight="balanced", random_state=0)
    full.fit(X, y)
    return full, auc, (Xte, yte, clf)


def rules_text(clf, feats: list[str], class_names: list[str]) -> str:
    txt = export_text(clf, feature_names=feats, decimals=2, show_weights=False)
    for c_i, name in enumerate(class_names):
        txt = txt.replace(f"class: {c_i}", f"=> {name}")
    return txt


def top_leaves(clf, X: pd.DataFrame, y: np.ndarray, positive: int = 1, k: int = 5) -> pd.DataFrame:
    """Các nhánh lá có tỉ lệ vào lệnh cao nhất, viết lại dạng điều kiện."""
    tree = clf.tree_
    feats = X.columns
    paths: dict[int, list[str]] = {}

    def walk(node, conds):
        if tree.children_left[node] == -1:
            paths[node] = conds
            return
        f, thr = feats[tree.feature[node]], tree.threshold[node]
        walk(tree.children_left[node], conds + [f"{f} <= {thr:.2f}"])
        walk(tree.children_right[node], conds + [f"{f} > {thr:.2f}"])

    walk(0, [])
    leaf = clf.apply(X)
    base = (y == positive).mean()
    rows = []
    for node, conds in paths.items():
        m = leaf == node
        if m.sum() == 0:
            continue
        rate = (y[m] == positive).mean()
        rows.append({"Điều kiện": " VÀ ".join(conds) or "(mọi nến)", "Số nến": int(m.sum()),
                     "Số lần vào lệnh": int((y[m] == positive).sum()), "Tỉ lệ vào lệnh": rate,
                     "Gấp so với ngẫu nhiên": rate / base if base > 0 else np.nan})
    t = pd.DataFrame(rows).sort_values("Tỉ lệ vào lệnh", ascending=False)
    return t[t["Số lần vào lệnh"] > 0].head(k)


def verdict(auc: float) -> str:
    if auc != auc:
        return "không đủ dữ liệu kiểm tra"
    if auc >= 0.85:
        return "**rất rõ** – quy tắc có tính máy móc cao"
    if auc >= 0.7:
        return "**khá rõ** – có mẫu hình, nhưng còn yếu tố khác chưa đo được"
    if auc >= 0.6:
        return "**yếu** – chỉ gợi ý xu hướng"
    return "**không tìm được** quy tắc từ các chỉ báo đang đo (có thể đánh tay/theo tin/dùng chỉ báo khác)"


def entry_rules(pos: pd.DataFrame, bars: dict, rep: Report, notes: list[str]) -> None:
    rep.h("9. Suy ra điều kiện vào lệnh")
    if not HAVE_SKLEARN:
        rep.p("Chưa cài scikit-learn (`pip install scikit-learn`) nên bỏ qua phần mô hình.")
    rep.p("Mọi đặc trưng được tính trên **nến đã đóng ngay trước lúc vào lệnh** (không nhìn trước tương lai). "
          "Quy tắc được học trên 70% dữ liệu đầu, kiểm tra trên 30% cuối; AUC 0.5 = đoán mò, 1.0 = hoàn hảo.")

    for sym, g in pos.groupby("symbol"):
        g = g.dropna(subset=["feat_bar_time"])
        rep.h(f"{sym}", 3)
        if len(g) < 20:
            rep.p(f"Chỉ có {len(g)} lệnh có đặc trưng — cần ≥ 20 (tốt nhất > 100) để suy luận.")
            continue
        feats = [f for f in MODEL_FEATURES if f in g.columns and g[f].notna().mean() > 0.9]

        b = bars.get(sym)
        if b is not None:
            b = b.copy()
            first = g.drop_duplicates("feat_bar_time").set_index("feat_bar_time")["dir"]
            b["y"] = b["feat_bar_time"].map(first).fillna(0).astype(int)
            b = b[b["feat_bar_time"] >= g["feat_bar_time"].min() - pd.Timedelta(days=1)].reset_index(drop=True)
            n_hit = int((b["y"] != 0).sum())
            rep.p(f"{len(b)} nến, trong đó {n_hit} nến có vào lệnh ({n_hit / len(b) * 100:.2f}%).")

            for d, name in [(1, "BUY"), (-1, "SELL")]:
                e = b[b["y"] == d]
                if len(e) < 10:
                    continue
                t = effect_table(e, b, feats).head(8)
                if t.empty:
                    continue
                rep.p(f"**Khác biệt lớn nhất khi {name}** (so với mọi nến):")
                rep.table(t.drop(columns="_f"))

            if HAVE_SKLEARN:
                for d, name in [(1, "BUY"), (-1, "SELL")]:
                    y = (b["y"] == d).astype(int).values
                    if y.sum() < 15:
                        continue
                    X = b[feats].fillna(b[feats].median())
                    clf, auc, _ = fit_tree(X, y, depth=4, min_leaf=max(5, int(y.sum() * 0.05)))
                    rep.p(f"**Mô hình vào lệnh {name}** – AUC kiểm tra = {auc:.2f} → {verdict(auc)}")
                    lv = top_leaves(clf, X, y)
                    if not lv.empty:
                        rep.table(lv, floatfmt="{:.3g}")
                        best = lv.iloc[0]
                        if auc == auc and auc >= 0.7:
                            notes.append(f"{sym} {name}: {best['Điều kiện']} → xác suất vào lệnh gấp "
                                         f"{best['Gấp so với ngẫu nhiên']:.0f} lần bình thường (AUC {auc:.2f}).")
                    imp = pd.Series(clf.feature_importances_, index=feats).sort_values(ascending=False)
                    imp = imp[imp > 0.02].head(8)
                    rep.p("Mức quan trọng: " + ", ".join(f"{label(f)} {v:.2f}" for f, v in imp.items()))
        else:
            rep.p("Không có file nến (`*_bars_*.csv`) → chỉ phân tích được hướng BUY/SELL, "
                  "không so sánh được với lúc KHÔNG vào lệnh.")

        # BUY hay SELL: dựa vào gì?
        if HAVE_SKLEARN and g["dir"].nunique() == 2 and min((g["dir"] > 0).sum(), (g["dir"] < 0).sum()) >= 10:
            X = g[feats].fillna(g[feats].median())
            y = (g["dir"] > 0).astype(int).values
            clf, auc, _ = fit_tree(X, y, depth=3, min_leaf=max(3, len(g) // 20))
            rep.p(f"**Chọn BUY hay SELL** – AUC kiểm tra = {auc:.2f} → {verdict(auc)}")
            rep.code(rules_text(clf, feats, ["SELL", "BUY"]))
            if auc == auc and auc >= 0.75:
                imp = pd.Series(clf.feature_importances_, index=feats).idxmax()
                notes.append(f"{sym}: hướng lệnh chủ yếu quyết định bởi {label(imp)} (AUC {auc:.2f}).")

    rep.p()
    rep.p("Cách đọc: `f_rsi <= 30.5` nghĩa là RSI(14) của nến vừa đóng ≤ 30.5. Các khoảng cách `_atr` "
          "tính theo bội số ATR(14) để so sánh được giữa lúc biến động mạnh/yếu.")


# ---------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=".", help="Thư mục chứa file CSV (MQL5/Files)")
    ap.add_argument("--prefix", default="tradelog")
    ap.add_argument("--out", default="report.md")
    args = ap.parse_args()

    deals, bars, orders, events, symbols = load(args.dir, args.prefix)
    pos = build_positions(deals)
    if pos.empty:
        sys.exit("Chưa có lệnh BUY/SELL nào trong file deals.")

    body = Report()
    notes = profile(pos, orders, events, symbols, body)
    entry_rules(pos, bars, body, notes)

    rep = Report()
    rep.p("# Báo cáo phân tích cách vào lệnh")
    rep.h("Nhận định chính")
    for n in notes or ["Chưa có nhận định nổi bật – xem chi tiết bên dưới."]:
        rep.p(f"- {n}")
    rep.p()
    rep.p("> Đây là mô hình **xấp xỉ** từ dữ liệu quan sát, không phải công thức gốc. "
          "Luôn backtest lại trên Strategy Tester trước khi dùng tiền thật.")
    rep.lines += body.lines

    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(rep.text())
    print(rep.text())
    print(f"\nĐã ghi báo cáo vào {args.out}")


if __name__ == "__main__":
    main()
