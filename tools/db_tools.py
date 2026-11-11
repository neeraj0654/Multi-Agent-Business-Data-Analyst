"""
tools/db_tools.py
─────────────────
PostgreSQL connection pool + query execution utilities.
Used by agents to safely run SQL against the business database.
"""
import os
import logging
from typing import Any
from contextlib import contextmanager

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

# ─── Connection Pool ──────────────────────────────────────────────────────────
_pool: pool.SimpleConnectionPool | None = None


def _get_pool() -> pool.SimpleConnectionPool:
    global _pool
    if _pool is None:
        _pool = pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=os.getenv("POSTGRES_HOST", "localhost"),
            port=int(os.getenv("POSTGRES_PORT", "5432")),
            dbname=os.getenv("POSTGRES_DB", "business_db"),
            user=os.getenv("POSTGRES_USER", "analyst"),
            password=os.getenv("POSTGRES_PASSWORD", "analyst_secret"),
        )
        logger.info("PostgreSQL connection pool initialized.")
    return _pool


@contextmanager
def get_connection():
    p = _get_pool()
    conn = p.getconn()
    try:
        yield conn
    finally:
        p.putconn(conn)


# ─── Schema Inspector ─────────────────────────────────────────────────────────
def get_schema_description() -> str:
    """
    Returns a detailed text description of the database schema,
    including table names, columns, types, and sample row counts.
    """
    schema_sql = """
        SELECT
            t.table_name,
            c.column_name,
            c.data_type,
            c.character_maximum_length,
            c.is_nullable,
            c.column_default
        FROM information_schema.tables t
        JOIN information_schema.columns c
            ON t.table_name = c.table_name
            AND t.table_schema = c.table_schema
        WHERE t.table_schema = 'public'
          AND t.table_type = 'BASE TABLE'
        ORDER BY t.table_name, c.ordinal_position;
    """
    view_sql = """
        SELECT table_name FROM information_schema.views
        WHERE table_schema = 'public';
    """
    with get_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(schema_sql)
            columns = cur.fetchall()

            cur.execute(view_sql)
            views = [r["table_name"] for r in cur.fetchall()]

            # Group by table
            tables: dict[str, list] = {}
            for row in columns:
                tables.setdefault(row["table_name"], []).append(row)

            # Row counts
            row_counts = {}
            for tname in tables:
                cur.execute(f"SELECT COUNT(*) FROM {tname}")
                row_counts[tname] = cur.fetchone()["count"]

    lines = ["=== DATABASE SCHEMA (business_db) ===\n"]
    for tname, cols in tables.items():
        lines.append(f"TABLE: {tname}  ({row_counts.get(tname, '?')} rows)")
        for col in cols:
            nullable = "" if col["is_nullable"] == "YES" else " NOT NULL"
            lines.append(f"  - {col['column_name']}: {col['data_type']}{nullable}")
        lines.append("")

    if views:
        lines.append(f"VIEWS: {', '.join(views)}")
        lines.append("  (Views pre-join sales + products + customers + employees)")

    return "\n".join(lines)


# ─── Query Executor ───────────────────────────────────────────────────────────
def execute_query(sql: str, params: tuple = ()) -> dict[str, Any]:
    """
    Execute a SELECT SQL query safely.
    Returns:
        {
            "success": bool,
            "columns": [...],
            "rows": [...],     # list of dicts
            "row_count": int,
            "error": str | None
        }
    """
    # Basic safety: only allow read operations
    sql_stripped = sql.strip().upper()
    if not sql_stripped.startswith("SELECT") and not sql_stripped.startswith("WITH"):
        return {
            "success": False,
            "columns": [],
            "rows": [],
            "row_count": 0,
            "error": "Only SELECT / WITH queries are permitted.",
        }

    try:
        with get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchmany(500)  # Cap at 500 rows for safety
                columns = [desc.name for desc in cur.description] if cur.description else []
                return {
                    "success": True,
                    "columns": columns,
                    "rows": [dict(r) for r in rows],
                    "row_count": len(rows),
                    "error": None,
                }
    except Exception as exc:
        logger.error("Query failed: %s\nSQL: %s", exc, sql)
        return {
            "success": False,
            "columns": [],
            "rows": [],
            "row_count": 0,
            "error": str(exc),
        }


def test_connection() -> bool:
    """Returns True if DB is reachable."""
    try:
        result = execute_query("SELECT 1 AS ping")
        return result["success"]
    except Exception:
        return False
