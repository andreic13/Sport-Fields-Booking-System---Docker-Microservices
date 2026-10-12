from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey
from .database import Base

class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user_profiles.id"), nullable=False)
    field_id = Column(Integer, nullable=False)
    date = Column(Date, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    
    # active / cancelled / expired
    status = Column(String, nullable=False, default="active")

# Definesc si importez in main si user_profiles pentru
# a verifica daca userul curent este admin
class UserProfile(Base):
    __tablename__ = "user_profiles"

    # index = True => pot face cautari rapide dupa acest camp
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String)
    role = Column(String) # user/admin