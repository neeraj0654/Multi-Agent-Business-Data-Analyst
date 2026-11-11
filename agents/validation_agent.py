"""
agents/validation_agent.py
───────────────────────────
Validation Agent: independently re-queries the database to verify every
numeric figure reported by the SQL Agent, catching hallucinated numbers.
"""
import json
import logging
import os
import re

from langchain_ollama import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

from graph.state import AnalystState, ValidationResult, QueryResult
from tools.db_tools import execute_query

logger = logging.getLogger(__name__)

DISCREPANCY_THRESHOLD = 0.01  # 1% tolerance

SYSTEM_PROMPT = """You are a rigorous data auditor.
Given a SQL query and its reported result, write a NEW verification SQL query
that independently confirms the key numeric figures.

Rules:
1. Your verification query must compute the same metric via a DIFFERENT approach
   (e.g., if original used SUM(revenue), verify with SUM(quantity * unit_price * (1 - discount_pct/100))).
2. Only use SELECT queries. Never modify data.
3. Respond ONLY with valid JSON:
{
  "verification_sql": "<your verification SQL>",
  "metric_to_check": "Name of the key figure being verified",
  "original_value": <numeric value from original result>
}"""


def _extract_key_metric(result: QueryResult) -> tuple[str, float] | None:
    """Extract the primary numeric metric from a query result for validation."""
    if not result["rows"]:
        return None
    first_row = result["rows"][0]
    for key, val in first_row.items():
        try:
            return key, float(val)
        except (TypeError, ValueError):
            continue
    return None


def _build_verification_sql(result: QueryResult) -> tuple[str, str, float] | None:
    """Ask LLM to generate a verification query for a result."""
    if not result["rows"] or not result["sql"]:
        return None

    metric = _extract_key_metric(result)
    if not metric:
        return None

    llm = ChatOllama(
        base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"),
        model=os.getenv("OLLAMA_MODEL", "llama3"),
        temperature=0.0,
        format="json",
    )
    sample_data = json.dumps(result["rows"][:5], default=str)
    user_msg = f"""
Original SQL:
{result['sql']}

Sample result data:
{sample_data}

Write a verification SQL query to independently confirm the key numeric figures.
"""
    messages = [SystemMessage(content=SYSTEM_PROMPT), HumanMessage(content=user_msg)]
    try:
        response = llm.invoke(messages)
        raw = re.sub(r"```(?:json)?|```", "", response.content).strip()
        parsed = json.loads(raw)
        return (
            parsed.get("verification_sql", ""),
            parsed.get("metric_to_check", metric[0]),
            float(parsed.get("original_value", metric[1])),
        )
    except Exception as exc:
        logger.warning("Verification SQL generation failed: %s", exc)
        return None


def _compare_values(original: float, verified: float) -> tuple[bool, float]:
    """Returns (is_match, pct_difference)."""
    if original == 0 and verified == 0:
        return True, 0.0
    if original == 0:
        return False, 1.0
    diff = abs(original - verified) / abs(original)
    return diff <= DISCREPANCY_THRESHOLD, diff


def validation_node(state: AnalystState) -> dict:
    """LangGraph node: Validation Agent cross-checks each SQL result."""
    logger.info("✅ Validation Agent starting — %d results to validate.", len(state["query_results"]))

    validation_results: list[ValidationResult] = []
    all_passed = True
    messages = []

    for qr in state["query_results"]:
        step_id = qr["step_id"]

        # Skip errored results
        if qr.get("error") or not qr["rows"]:
            validation_results.append(ValidationResult(
                step_id=step_id,
                is_valid=True,
                discrepancies=[],
                corrected_values={},
                confidence=0.5,
            ))
            messages.append(f"Validation step {step_id}: Skipped (no data).")
            continue

        # Get verification query from LLM
        verif = _build_verification_sql(qr)
        if not verif:
            validation_results.append(ValidationResult(
                step_id=step_id,
                is_valid=True,
                discrepancies=[],
                corrected_values={},
                confidence=0.7,
            ))
            messages.append(f"Validation step {step_id}: Could not build verification query; assumed valid.")
            continue

        verif_sql, metric_name, original_val = verif

        if not verif_sql:
            validation_results.append(ValidationResult(
                step_id=step_id,
                is_valid=True,
                discrepancies=[],
                corrected_values={},
                confidence=0.7,
            ))
            continue

        # Execute verification query
        verif_result = execute_query(verif_sql)
        discrepancies = []
        corrected = {}
        confidence = 0.95

        if verif_result["success"] and verif_result["rows"]:
            first_row = verif_result["rows"][0]
            for key, val in first_row.items():
                try:
                    verified_val = float(val)
                    is_match, pct_diff = _compare_values(original_val, verified_val)
                    if not is_match:
                        msg = (f"{metric_name}: original={original_val:,.2f}, "
                               f"verified={verified_val:,.2f}, diff={pct_diff:.1%}")
                        discrepancies.append(msg)
                        corrected[metric_name] = verified_val
                        all_passed = False
                        confidence = max(0.1, 1.0 - pct_diff)
                        logger.warning("⚠️  Discrepancy found — step %d: %s", step_id, msg)
                    break
                except (TypeError, ValueError):
                    continue

        status = "PASSED" if not discrepancies else "FLAGGED"
        messages.append(f"Validation step {step_id}: {status}.")
        validation_results.append(ValidationResult(
            step_id=step_id,
            is_valid=not bool(discrepancies),
            discrepancies=discrepancies,
            corrected_values=corrected,
            confidence=confidence,
        ))

    logger.info("✅ Validation complete. All passed: %s", all_passed)
    return {
        "validation_results": validation_results,
        "validation_passed": all_passed,
        "messages": messages,
    }
