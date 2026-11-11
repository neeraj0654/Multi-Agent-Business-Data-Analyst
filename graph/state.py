"""
graph/state.py
──────────────
Shared LangGraph state schema for the Multi-Agent Business Analyst pipeline.
All agents read from and write to this TypedDict.
"""
from __future__ import annotations
from typing import Any, Annotated
from typing_extensions import TypedDict
import operator


class PlanStep(TypedDict):
    """A single step produced by the Planner Agent."""
    step_id: int
    description: str           # Human-readable description
    sql_hint: str              # Optional SQL hint / table suggestions
    is_complete: bool


class QueryResult(TypedDict):
    """Result from one SQL query execution."""
    step_id: int
    sql: str                   # The generated SQL
    columns: list[str]
    rows: list[dict[str, Any]]
    row_count: int
    summary: str               # LLM-written summary of this result
    error: str | None


class ValidationResult(TypedDict):
    """Validation agent output for one query result."""
    step_id: int
    is_valid: bool
    discrepancies: list[str]   # List of detected issues
    corrected_values: dict[str, Any]
    confidence: float          # 0.0–1.0


class AnalystState(TypedDict):
    """The full shared state passed through the LangGraph workflow."""
    # Input
    question: str              # Raw user business question
    schema: str                # DB schema description string

    # Planner output
    plan: list[PlanStep]
    plan_summary: str

    # SQL Agent output (accumulated across steps)
    query_results: Annotated[list[QueryResult], operator.add]

    # Validation Agent output
    validation_results: Annotated[list[ValidationResult], operator.add]
    validation_passed: bool

    # Report Agent output
    report_markdown: str       # Final Markdown report
    chart_paths: list[str]     # Absolute paths to generated charts
    report_summary: str        # Short executive summary

    # Control flow
    current_step: int
    retry_count: int
    messages: Annotated[list[str], operator.add]  # Debug log
    error: str | None
