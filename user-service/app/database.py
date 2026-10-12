from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

DATABASE_URL = os.environ["DATABASE_URL"]

# configurare baza de date
engine = create_engine( # conexiune la db
    DATABASE_URL,
    pool_pre_ping=True, # verifica daca conexiunea e vie, altfel reconectare
    pool_recycle=1800) # recicleaza conexiunea la 30 min
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# base = clasa de baza pentru modelele sqlalchemy
Base = declarative_base()