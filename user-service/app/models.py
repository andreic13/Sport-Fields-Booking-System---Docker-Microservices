from sqlalchemy import Column, Integer, String
from .database import Base

class UserProfile(Base):
    __tablename__ = "user_profiles"

    # index = True => pot face cautari rapide dupa acest camp
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String)
    role = Column(String) # user/admin