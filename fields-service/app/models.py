from sqlalchemy import Column, Integer, String, Float
from .database import Base

class Field(Base):
    __tablename__ = "fields"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    location = Column(String, nullable=False)
    sport = Column(String, nullable=False)
    price_per_hour = Column(Float, nullable=False)

# Definesc si importez in main si user_profiles pentru
# a verifica daca userul curent este admin
class UserProfile(Base):
    __tablename__ = "user_profiles"

    # index = True => pot face cautari rapide dupa acest camp
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String)
    role = Column(String) # user/admin