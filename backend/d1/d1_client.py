"""Cloudflare D1 REST API Client.

A thin, isolated wrapper around the Cloudflare D1 REST API providing:
- query(sql, params)
- execute(sql, params)
- batch(statements)
- Configurable timeouts and retries with exponential backoff
- Clear domain exceptions (D1Error, D1ConnectionError, D1QueryError, D1ConfigurationError)
"""
import logging
import os
import random
import time
from typing import Any, Dict, List, Optional, Tuple, Union

import httpx
from config import get_settings

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Exceptions
# ─────────────────────────────────────────────────────────────────────────────

class D1Error(Exception):
    """Base exception for all D1 operations."""
    pass


class D1ConfigurationError(D1Error):
    """Raised when Cloudflare credentials or database ID are missing or invalid."""
    pass


class D1ConnectionError(D1Error):
    """Raised on network failure, timeout, or unreachable D1 API."""
    pass


class D1QueryError(D1Error):
    """Raised when D1 execution reports an error (syntax, constraint, etc.)."""
    def __init__(self, message: str, sql: Optional[str] = None, errors: Optional[List[Dict[str, Any]]] = None):
        super().__init__(message)
        self.sql = sql
        self.errors = errors or []


# ─────────────────────────────────────────────────────────────────────────────
# D1Client
# ─────────────────────────────────────────────────────────────────────────────

class D1Client:
    def __init__(
        self,
        account_id: Optional[str] = None,
        database_id: Optional[str] = None,
        api_token: Optional[str] = None,
        timeout_seconds: float = 10.0,
        max_retries: int = 3,
        http_client: Optional[httpx.Client] = None,
    ):
        settings = get_settings()
        self.account_id = account_id if account_id is not None else (settings.CF_ACCOUNT_ID or os.getenv("CF_ACCOUNT_ID", ""))
        self.database_id = database_id if database_id is not None else (settings.CF_D1_DATABASE_ID or os.getenv("CF_D1_DATABASE_ID", ""))
        self.api_token = api_token if api_token is not None else (settings.CF_API_TOKEN or os.getenv("CF_API_TOKEN", ""))
        self.timeout_seconds = timeout_seconds
        self.max_retries = max_retries

        self._client = http_client or httpx.Client(timeout=self.timeout_seconds)

    @property
    def is_configured(self) -> bool:
        """True if credentials and database ID are non-empty."""
        return bool(self.account_id and self.database_id and self.api_token)

    @property
    def endpoint_url(self) -> str:
        if not self.is_configured:
            raise D1ConfigurationError(
                "Cloudflare D1 is not fully configured. Ensure CF_ACCOUNT_ID, "
                "CF_D1_DATABASE_ID, and CF_API_TOKEN are set in .env."
            )
        return f"https://api.cloudflare.com/client/v4/accounts/{self.account_id}/d1/database/{self.database_id}/query"

    def _get_headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }

    def _send_with_retry(self, payload: Union[Dict[str, Any], List[Dict[str, Any]]]) -> Dict[str, Any]:
        """Sends POST request to D1 query endpoint with exponential backoff on transient errors."""
        url = self.endpoint_url
        headers = self._get_headers()

        last_exc: Optional[Exception] = None

        for attempt in range(self.max_retries + 1):
            try:
                resp = self._client.post(url, json=payload, headers=headers)

                # Transient server errors: 500, 502, 503, 504, 429
                if resp.status_code in (429, 500, 502, 503, 504) and attempt < self.max_retries:
                    delay = (0.2 * (2 ** attempt)) + random.uniform(0.05, 0.15)
                    logger.warning(
                        "[d1] HTTP %d from D1 API, retrying (%d/%d) in %.2fs...",
                        resp.status_code, attempt + 1, self.max_retries, delay
                    )
                    time.sleep(delay)
                    continue

                if not resp.is_success:
                    try:
                        err_data = resp.json()
                        errors = err_data.get("errors", [])
                        err_msg = "; ".join(e.get("message", "Unknown error") for e in errors) or resp.text
                    except Exception:
                        errors = []
                        err_msg = resp.text
                    raise D1QueryError(f"D1 API returned HTTP {resp.status_code}: {err_msg}", errors=errors)

                data = resp.json()
                if not data.get("success", False):
                    errors = data.get("errors", [])
                    err_msg = "; ".join(e.get("message", "Unknown error") for e in errors)
                    raise D1QueryError(f"D1 query execution failed: {err_msg}", errors=errors)

                return data

            except (httpx.TimeoutException, httpx.NetworkError) as net_err:
                last_exc = net_err
                if attempt < self.max_retries:
                    delay = (0.2 * (2 ** attempt)) + random.uniform(0.05, 0.15)
                    logger.warning(
                        "[d1] Network/timeout error: %s, retrying (%d/%d) in %.2fs...",
                        net_err, attempt + 1, self.max_retries, delay
                    )
                    time.sleep(delay)
                else:
                    raise D1ConnectionError(f"Failed to connect to D1 API after {self.max_retries + 1} attempts: {net_err}") from net_err

        raise D1ConnectionError(f"D1 request failed after {self.max_retries + 1} attempts: {last_exc}")

    def query(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        """Executes a SQL query and returns rows as a list of dicts."""
        res = self.execute(sql, params)
        return res.get("results", [])

    def execute(self, sql: str, params: Optional[List[Any]] = None) -> Dict[str, Any]:
        """Executes a SQL query and returns raw result dict containing 'results', 'changes', 'meta'."""
        body = {"sql": sql, "params": params or []}
        data = self._send_with_retry(body)

        result_list = data.get("result", [])
        if not result_list:
            return {"results": [], "changes": 0, "meta": {}}

        first_res = result_list[0]
        rows = first_res.get("results", [])
        meta = first_res.get("meta", {})
        changes = meta.get("changes", 0)

        return {
            "results": rows,
            "changes": changes,
            "last_row_id": meta.get("last_row_id"),
            "meta": meta,
        }

    def batch(
        self,
        statements: List[Union[Tuple[str, List[Any]], Dict[str, Any]]],
    ) -> List[Dict[str, Any]]:
        """Executes multiple SQL statements in a batch request, with sequential fallback if array body is rejected."""
        if not statements:
            return []

        formatted: List[Dict[str, Any]] = []
        for stmt in statements:
            if isinstance(stmt, tuple):
                sql = stmt[0]
                params = stmt[1] if len(stmt) > 1 else []
                formatted.append({"sql": sql, "params": params})
            elif isinstance(stmt, dict):
                formatted.append({"sql": stmt["sql"], "params": stmt.get("params", [])})
            else:
                raise ValueError("Statements must be (sql, params) tuples or {'sql': ..., 'params': ...} dicts")

        try:
            data = self._send_with_retry(formatted)
            result_list = data.get("result", [])
            return result_list
        except D1QueryError as q_err:
            # If Cloudflare REST API rejects array payload (e.g. Expected object, received array),
            # fall back to executing sequentially via execute()
            results: List[Dict[str, Any]] = []
            for item in formatted:
                res = self.execute(item["sql"], item["params"])
                results.append(res)
            return results


_d1_singleton: Optional[D1Client] = None


def get_d1_client() -> D1Client:
    """Returns the singleton D1Client instance."""
    global _d1_singleton
    if _d1_singleton is None:
        _d1_singleton = D1Client()
    return _d1_singleton
