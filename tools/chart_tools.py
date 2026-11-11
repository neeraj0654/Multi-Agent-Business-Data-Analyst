"""
tools/chart_tools.py
─────────────────────
Chart generation utilities for the Report Agent.
Produces Matplotlib figures saved as PNG files.
"""
import os
import uuid
import logging
from pathlib import Path
from typing import Any

import pandas as pd
import matplotlib
matplotlib.use("Agg")  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns

logger = logging.getLogger(__name__)

CHARTS_DIR = Path(os.getenv("CHARTS_DIR", "/app/charts"))
CHARTS_DIR.mkdir(parents=True, exist_ok=True)

# ─── Colour palette ───────────────────────────────────────────────────────────
PALETTE = ["#6C63FF", "#FF6584", "#43AA8B", "#F9C74F", "#577590", "#F3722C", "#90BE6D"]
plt.rcParams.update({
    "figure.facecolor": "#1E1E2E",
    "axes.facecolor":   "#2A2A3E",
    "axes.edgecolor":   "#44475A",
    "axes.labelcolor":  "#CDD6F4",
    "xtick.color":      "#BAC2DE",
    "ytick.color":      "#BAC2DE",
    "text.color":       "#CDD6F4",
    "grid.color":       "#44475A",
    "grid.linewidth":   0.5,
    "font.family":      "DejaVu Sans",
    "font.size":        10,
})


def _save_fig(fig, name_hint: str = "chart") -> str:
    fname = CHARTS_DIR / f"{name_hint}_{uuid.uuid4().hex[:8]}.png"
    fig.savefig(fname, bbox_inches="tight", dpi=130)
    plt.close(fig)
    logger.info("Chart saved: %s", fname)
    return str(fname)


# ─── Bar Chart ────────────────────────────────────────────────────────────────
def create_bar_chart(
    labels: list[str],
    values: list[float],
    title: str = "Bar Chart",
    x_label: str = "",
    y_label: str = "",
    horizontal: bool = False,
) -> str:
    fig, ax = plt.subplots(figsize=(10, 5))
    colors = (PALETTE * ((len(labels) // len(PALETTE)) + 1))[:len(labels)]
    if horizontal:
        bars = ax.barh(labels, values, color=colors, edgecolor="#1E1E2E", linewidth=0.5)
        ax.set_xlabel(y_label)
        ax.set_ylabel(x_label)
        for bar in bars:
            w = bar.get_width()
            ax.text(w * 1.01, bar.get_y() + bar.get_height() / 2,
                    f"{w:,.0f}", va="center", fontsize=8, color="#CDD6F4")
    else:
        bars = ax.bar(labels, values, color=colors, edgecolor="#1E1E2E", linewidth=0.5)
        ax.set_xlabel(x_label)
        ax.set_ylabel(y_label)
        for bar in bars:
            h = bar.get_height()
            ax.text(bar.get_x() + bar.get_width() / 2, h * 1.01,
                    f"{h:,.0f}", ha="center", fontsize=8, color="#CDD6F4")
        ax.set_xticklabels(labels, rotation=30, ha="right")

    ax.set_title(title, fontsize=14, fontweight="bold", pad=12)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax.grid(axis="x" if horizontal else "y", alpha=0.4)
    fig.tight_layout()
    return _save_fig(fig, "bar")


# ─── Line Chart ───────────────────────────────────────────────────────────────
def create_line_chart(
    x_values: list,
    y_series: dict[str, list[float]],
    title: str = "Line Chart",
    x_label: str = "",
    y_label: str = "",
) -> str:
    fig, ax = plt.subplots(figsize=(11, 5))
    for i, (name, vals) in enumerate(y_series.items()):
        color = PALETTE[i % len(PALETTE)]
        ax.plot(x_values, vals, marker="o", label=name, color=color,
                linewidth=2, markersize=5)
        ax.fill_between(x_values, vals, alpha=0.08, color=color)

    ax.set_title(title, fontsize=14, fontweight="bold", pad=12)
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax.legend(framealpha=0.3)
    ax.grid(alpha=0.4)
    if len(x_values) > 6:
        ax.set_xticklabels(x_values, rotation=30, ha="right")
    fig.tight_layout()
    return _save_fig(fig, "line")


# ─── Pie / Donut Chart ────────────────────────────────────────────────────────
def create_pie_chart(
    labels: list[str],
    values: list[float],
    title: str = "Pie Chart",
    donut: bool = True,
) -> str:
    fig, ax = plt.subplots(figsize=(8, 6))
    colors = (PALETTE * ((len(labels) // len(PALETTE)) + 1))[:len(labels)]
    wedges, texts, autotexts = ax.pie(
        values, labels=labels, colors=colors,
        autopct="%1.1f%%", startangle=140,
        wedgeprops={"edgecolor": "#1E1E2E", "linewidth": 1.5},
        pctdistance=0.75,
    )
    for t in autotexts:
        t.set_color("#1E1E2E")
        t.set_fontweight("bold")
    if donut:
        centre = plt.Circle((0, 0), 0.5, fc="#1E1E2E")
        ax.add_patch(centre)
    ax.set_title(title, fontsize=14, fontweight="bold", pad=12)
    fig.tight_layout()
    return _save_fig(fig, "pie")


# ─── Grouped Bar Chart ────────────────────────────────────────────────────────
def create_grouped_bar_chart(
    df_data: list[dict],
    group_col: str,
    value_col: str,
    hue_col: str,
    title: str = "Grouped Bar Chart",
    x_label: str = "",
    y_label: str = "",
) -> str:
    df = pd.DataFrame(df_data)
    fig, ax = plt.subplots(figsize=(12, 5))
    pivot = df.pivot(index=group_col, columns=hue_col, values=value_col).fillna(0)
    pivot.plot(kind="bar", ax=ax, color=PALETTE[:len(pivot.columns)],
               edgecolor="#1E1E2E", linewidth=0.5)
    ax.set_title(title, fontsize=14, fontweight="bold", pad=12)
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
    ax.set_xticklabels(ax.get_xticklabels(), rotation=30, ha="right")
    ax.legend(title=hue_col, framealpha=0.3)
    ax.grid(axis="y", alpha=0.4)
    fig.tight_layout()
    return _save_fig(fig, "grouped_bar")


# ─── Auto Chart (infers type from data shape) ─────────────────────────────────
def auto_chart(
    rows: list[dict],
    title: str = "Analysis",
    x_col: str | None = None,
    y_col: str | None = None,
) -> str | None:
    """
    Heuristically picks the best chart type for a query result set.
    Returns the saved file path, or None if no chart was suitable.
    """
    if not rows or len(rows) < 2:
        return None

    df = pd.DataFrame(rows)
    numeric_cols = df.select_dtypes(include="number").columns.tolist()
    text_cols = df.select_dtypes(exclude="number").columns.tolist()

    if not numeric_cols:
        return None

    y = y_col or numeric_cols[0]
    x = x_col or (text_cols[0] if text_cols else df.columns[0])

    if str(x).lower() in ("sale_month", "sale_quarter", "sale_date", "month", "quarter", "date"):
        x_vals = df[x].astype(str).tolist()
        return create_line_chart(x_vals, {y: df[y].tolist()}, title=title,
                                 x_label=x, y_label=y)
    elif len(df) <= 8:
        return create_pie_chart(df[x].astype(str).tolist(), df[y].tolist(), title=title)
    else:
        return create_bar_chart(df[x].astype(str).tolist(), df[y].tolist(),
                                title=title, x_label=x, y_label=y, horizontal=len(df) > 10)
