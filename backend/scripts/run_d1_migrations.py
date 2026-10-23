import os
import sys

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from d1.d1_client import get_d1_client

def split_sql_statements(sql_text: str):
    statements = []
    current = []
    for line in sql_text.splitlines():
        trimmed = line.strip()
        if not trimmed or trimmed.startswith("--"):
            continue
        current.append(line)
        if trimmed.endswith(";"):
            stmt = "\n".join(current).strip()
            if stmt:
                statements.append(stmt)
            current = []
    if current:
        stmt = "\n".join(current).strip()
        if stmt:
            statements.append(stmt)
    return statements

def run_migrations():
    client = get_d1_client()
    if not client.is_configured:
        print("Error: Cloudflare D1 client is not configured!")
        sys.exit(1)

    migrations_dir = os.path.join(backend_dir, "d1", "migrations")
    migration_files = sorted([f for f in os.listdir(migrations_dir) if f.endswith(".sql")])

    print(f"Applying {len(migration_files)} migrations to Cloudflare D1...")
    for mf in migration_files:
        path = os.path.join(migrations_dir, mf)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        stmts = split_sql_statements(content)
        print(f"--- Running {mf} ({len(stmts)} statements) ---")
        for i, stmt in enumerate(stmts, 1):
            try:
                res = client.execute(stmt)
                print(f"  [{i}/{len(stmts)}] OK: {stmt.splitlines()[0][:60]}...")
            except Exception as e:
                print(f"  [{i}/{len(stmts)}] FAILED: {stmt.splitlines()[0][:60]}...\n  Error: {e}")
                raise

    print("\nVerifying created tables...")
    tables = client.query("SELECT name FROM sqlite_master WHERE type='table'")
    table_names = [t["name"] for t in tables]
    print("Tables currently in D1:", table_names)

    achievements = client.query("SELECT key, title FROM achievement_catalog")
    print(f"Achievements catalog count: {len(achievements)}")
    for a in achievements:
        print(f"  - {a['key']}: {a['title']}")

if __name__ == "__main__":
    run_migrations()
