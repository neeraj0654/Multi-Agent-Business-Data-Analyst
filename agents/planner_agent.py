"""
agents/planner_agent.py
────────────────────────
Planner Agent: breaks a business question into concrete, executable sub-steps.
Uses an Ollama LLM with structured JSON output.
"""
import json
import logging
import os
import re

from langchain_ollama import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

from graph.state import AnalystState, PlanStep

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an expert business intelligence planner.
Your job is to decompose a business question into 3–5 concrete, executable sub-steps
that can each be answered by a single SQL query against a PostgreSQL database.

For each step, provide:
- step_id: integer starting at 1
- description: clear English description of what to query
- sql_hint: which tables/views to use and any key columns (e.g. "Use v_sales_summary, filter by sale_year=2023")

ALWAYS respond with valid JSON in this exact format:
{
  "plan_summary": "Brief overview of your approach",
  "steps": [
    {"step_id": 1, "description": "...", "sql_hint": "..."},
    ...
  ]
}

Database tables available:
- sales (sale_id, order_id, customer_id, product_id, employee_id, quantity, unit_price, discount_pct, revenue, cost, profit, sale_date, ship_date, status, region, channel)
- products (product_id, sku, product_name, category, sub_category, unit_price, unit_cost, stock_quantity)
- customers (customer_id, customer_name, segment, region, country, acquisition_channel, lifetime_value)
- employees (employee_id, full_name, department, role, region, hire_date, salary, performance_score)

Useful pre-built views (recommended):
- v_sales_summary: joins sales + products + customers + employees; has sale_month, sale_quarter, sale_year columns
- v_product_performance: product-level revenue, profit, margin stats
- v_customer_analytics: customer-level order counts, revenue, avg order value

Keep steps focused and practical. Each step should answer a distinct part of the question."""


def planner_node(state: AnalystState) -> dict:
    """LangGraph node: runs the Planner Agent."""
    logger.info("🧠 Planner Agent starting...")

    llm = ChatOllama(
        base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"),
        model=os.getenv("OLLAMA_MODEL", "llama3"),
        temperature=0.1,
        format="json",
    )

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=f"Business Question: {state['question']}"),
    ]

    response = llm.invoke(messages)
    raw = response.content

    try:
        # Strip markdown code fences if model wrapped output
        clean = re.sub(r"```(?:json)?|```", "", raw).strip()
        parsed = json.loads(clean)
        steps: list[PlanStep] = [
            PlanStep(
                step_id=s["step_id"],
                description=s["description"],
                sql_hint=s.get("sql_hint", ""),
                is_complete=False,
            )
            for s in parsed.get("steps", [])
        ]
        plan_summary = parsed.get("plan_summary", "")
    except json.JSONDecodeError:
        logger.warning("Planner returned non-JSON; creating single-step plan.")
        steps = [PlanStep(step_id=1, description=state["question"],
                          sql_hint="Use v_sales_summary", is_complete=False)]
        plan_summary = "Single-step analysis."

    logger.info("🧠 Planner produced %d steps.", len(steps))
    return {
        "plan": steps,
        "plan_summary": plan_summary,
        "current_step": 0,
        "messages": [f"Planner: {len(steps)} steps planned."],
    }
