import os
import time
from sqlalchemy import create_engine, text

DATABASE_URL = os.environ["DATABASE_URL"]
SLEEP_SECONDS = 30

SQL = text("""
UPDATE bookings
SET status = 'expired'
WHERE status = 'active'
  AND (date + end_time) <= NOW()
""")

# helper in caz ca db nu e up cand porneste worker-ul
def create_db_engine():
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    try:
        with engine.begin() as conn:
            result = conn.execute(SQL)
            return result.rowcount or 0
    finally:
        engine.dispose() # inchid conexiunea dupa executie

# try sa expire bookings la fiecare SLEEP_SECONDS
def main():
    while True:
        try:
            expired_count = create_db_engine()
            if expired_count > 0:
                print(f"Expired {expired_count} bookings.", flush=True)
        except Exception as e:
            print(f"Database is not up yet..", flush=True)
        time.sleep(SLEEP_SECONDS)

if __name__ == "__main__":
    main()