"""
agents/sql_agent.py
────────────────────
SQL Agent: for each plan step, generates a SQL query using an LLM,
executes it against PostgreSQL, and summarises the result.
"""
import json
import logging
import os
import re

from langchain_ollama import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

from graph.state import AnalystState, QueryResult
from tools.db_tools import execute_query, get_schema_description

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an expert PostgreSQL analyst.
Given a step description and database schema, generate a correct, efficient SQL query.

Rules:
1. Only use SELECT or WITH (CTE) queries — never INSERT/UPDATE/DELETE/DROP.
2. Always add LIMIT 50 unless the question requires all rows for aggregation.
3. Prefer the pre-built views: v_sales_summary, v_product_performance, v_customer_analytics.
4. For revenue/profit totals, use SUM(). For counts, use COUNT(). Round money to 2 decimals.
5. Format dates as YYYY-MM or YYYY-QN where appropriate.

Respond ONLY with valid JSON:
{
  "sql": "<your SQL query here>",
  "explanation": "Brief explanation of what this query does"
}"""

SUMMARY_PROMPT = """You are a data interpreter. Given a SQL query result, write a concise 2-3 sentence
business insight summary. Focus on the numbers and what they mean for the business.
Do NOT invent numbers — only use what is in the data."""


def _generate_sql(step_description: str, sql_hint: str, schema: str) -> tuple[str, str]:
    """Call LLM to generate SQL for one plan step."""
    llm = ChatOllama(
        base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"),
        model=os.getenv("OLLAMA_MODEL", "llama3"),
        temperature=0.0,
        format="json",
    )
    user_msg = f"""
Database Schema:
{schema}

Step to execute: {step_description}
SQL Hint: {sql_hint}

Generate the SQL query.
"""
    messages = [SystemMessage(content=SYSTEM_PROMPT), HumanMessage(content=user_msg)]
    response = llm.invoke(messages)
    raw = re.sub(r"```(?:json|sql)?|```", "", response.content).strip()
    try:
        parsed = json.loads(raw)
        return parsed.get("sql", ""), parsed.get("explanation", "")
    except json.JSONDecodeError:
        # Try to extract SQL directly from text
        sql_match = re.search(r"SELECT.*?(?=;|$)", raw, re.IGNORECASE | re.DOTALL)
        if sql_match:
            return sql_match.group(0).strip(), "SQL extracted from response."
        return "", "Failed to parse SQL from LLM response."


def _summarise_result(step_description: str, sql: str, rows: list[dict]) -> str:
    """Ask the LLM to summarise the query result in plain English."""
    if not rows:
        return "No data was returned for this query."

    llm = ChatOllama(
        base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"),
        model=os.getenv("OLLAMA_MODEL", "llama3"),
        temperature=0.2,
    )
    # Provide at most 20 rows to avoid context overflow
    sample = json.dumps(rows[:20], default=str, indent=2)
    user_msg = f"""
Step: {step_description}
SQL used: {sql}
Data returned ({len(rows)} rows, showing up to 20):
{sample}

Write a concise business insight summary.
"""
    messages = [SystemMessage(content=SUMMARY_PROMPT), HumanMessage(content=user_msg)]
    response = llm.invoke(messages)
    return response.content.strip()


def sql_node(state: AnalystState) -> dict:
    """LangGraph node: SQL Agent processes ALL plan steps sequentially."""
    logger.info("🗄️  SQL Agent starting — %d steps to process.", len(state["plan"]))

    schema = state.get("schema") or get_schema_description()
    new_results: list[QueryResult] = []
    messages = []

    for step in state["plan"]:
        logger.info("  Step %d: %s", step["step_id"], step["description"])

        # 1. Generate SQL
        sql, explanation = _generate_sql(step["description"], step["sql_hint"], schema)

        if not sql:
            new_results.append(QueryResult(
                step_id=step["step_id"],
                sql="",
                columns=[],
                rows=[],
                row_count=0,
                summary=f"SQL generation failed: {explanation}",
                error="LLM did not produce a valid SQL query.",
            ))
            messages.append(f"SQL Agent step {step['step_id']}: SQL generation failed.")
            continue

        # 2. Execute
        result = execute_query(sql)

        # 3. Summarise
        summary = _summarise_result(step["description"], sql, result["rows"])

        new_results.append(QueryResult(
            step_id=step["step_id"],
            sql=sql,
            columns=result["columns"],
            rows=result["rows"],
            row_count=result["row_count"],
            summary=summary,
            error=result.get("error"),
        ))
        messages.append(
            f"SQL Agent step {step['step_id']}: {result['row_count']} rows returned."
        )

    logger.info("🗄️  SQL Agent complete.")
    return {
        "query_results": new_results,
        "schema": schema,
        "messages": messages,
    }
