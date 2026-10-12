from datetime import datetime
import os
from fastapi import FastAPI, Depends, HTTPException
from fastapi.params import Header
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import text # pentru pg_advisory_xact_lock

from .database import Base, engine, SessionLocal
from .models import Booking, UserProfile
from .auth import get_current_user

from .redis_hold import start_hold, validate_hold, cancel_hold

from pydantic import BaseModel # vreau sa dau hold_token in body pt securitate

from .rabbitmq_pub import publish_event
import os

# token pentru a accesa un endpoint intern
INTERNAL_TOKEN = os.getenv("INTERNAL_TOKEN", "secret123")

# creez tabelele in db daca nu exista
Base.metadata.create_all(bind=engine)

app = FastAPI()

# sesiune db pentru fiecare request
def get_db():
    db = SessionLocal()
    try:
        yield db # returneaza sesiunea db la functiile care o apeleaza
    finally:
        db.close() # inchid sesiunea dupa incheierea functiei apelante

# helper pt a crea user-ul in db daca nu exista
def create_or_return_user_db(db: Session, current_user:dict) -> UserProfile:
    username = current_user.get("username")
    if not username:
        raise HTTPException(401, "Invalid token: missing username")

    # daca userul exista deja, il returnez
    user = db.query(UserProfile).filter_by(username=username).first()
    if user:
        return user

    email = current_user.get("email")

    # rol default pentru user nou
    role = "user"

    user = UserProfile(username=username, email=email, role=role)

    try:
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    except IntegrityError:
        # daca 2 request-uri creeaza acelasi user in acelasi timp
        # atunci user nu poate fi adaugat si il iau din db
        db.rollback()
        user = db.query(UserProfile).filter_by(username=username).first()
        if not user:
            raise
        return user

# verificare rol admin in baza de date userprofiles
def require_admin(db: Session, current_user):
    me = create_or_return_user_db(db, current_user)
    if me.role != "admin":
        raise HTTPException(403, "Admin privileges required")

# functie ca sa nu mai iau mereu userul curent din db manual
def get_me(db: Session, current_user):
    me = create_or_return_user_db(db, current_user)
    
    return me

# verifica daca un interval orar se intersecteaza cu alt interval
def overlaps(start1, end1, start2, end2):
    return start1 < end2 and start2 < end1

# dau hold_token in body pentru securitate
class HoldTokenBodyRequest(BaseModel):
    hold_token: str

# endpoint intern pentru a verifica daca o rezervare e inca activa
@app.get("/internal/bookings/{booking_id}")
def internal_check_booking_active(
    booking_id: int,
    token: str = Header(None),
    db: Session = Depends(get_db)
):
    if token != INTERNAL_TOKEN:
        raise HTTPException(403, "Invalid internal token")

    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(404, "Booking not found")

    return {"booking_id": booking.id, "is_active": booking.status == "active"}

@app.get("/")
def root():
    return {"message": "Bookings service is running"}

# verifica disponibilitatea unui teren pe o anumita data (minim user logat)
# ! folosesc get_current_user pentru a ma asigura ca userul este logat
@app.get("/bookings/availability/{field_id}")
def check_availability(
    field_id: int,
    date: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # parse date
    try:
        d = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(400, "Invalid date format. Use YYYY-MM-DD")

    # ia toate rezervarile active pentru terenul cerut in ziua respectiva
    bookings = db.query(Booking).filter(
        Booking.field_id == field_id,
        Booking.date == d,
        Booking.status == "active"
    ).all()

    # intorc lista cu intervalele ocupate
    return {
        "field_id": field_id,
        "date": str(d),
        "busy_intervals": [
            {"start_time": str(b.start_time), "end_time": str(b.end_time)}
            for b in bookings
        ]
    }

# incepe hold pe un teren (minim user logat)
@app.post("/bookings/hold/start")
def hold_start(
    field_id: int,
    current_user = Depends(get_current_user)
):
    
    token = start_hold(field_id, current_user["username"], ttl_seconds=180)
    if not token:
        raise HTTPException(409, "Field is already in reservation process (hold active)")
    return {"message": "Hold acquired", "field_id": field_id, "hold_token": token, "ttl_seconds": 180}

# anuleaza hold pe un teren (minim user logat)
@app.post("/bookings/hold/cancel")
def hold_cancel(
    req: HoldTokenBodyRequest, # body cu hold_token
    field_id: int,
    current_user = Depends(get_current_user)
):
    hold_token = req.hold_token

    # nu permite altui user sa elibereze hold-ul (validare owner)
    if not validate_hold(field_id, current_user["username"], hold_token):
        raise HTTPException(403, "Invalid hold token or not owner")

    ok = cancel_hold(field_id, hold_token)
    if not ok:
        raise HTTPException(409, "Hold already expired or not owned")
    return {"message": "Hold released", "field_id": field_id}

# creeaza rezervare (minim user logat + hold valid pe teren)
@app.post("/bookings/add")
def create_booking(
    req: HoldTokenBodyRequest, # body cu hold_token
    field_id: int,
    date: str,
    start_time: str,
    end_time: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    hold_token = req.hold_token

    me = get_me(db, current_user)

    # parse date + time
    try:
        d = datetime.strptime(date, "%Y-%m-%d").date()
        st = datetime.strptime(start_time, "%H:%M").time()
        et = datetime.strptime(end_time, "%H:%M").time()
    except ValueError:
        raise HTTPException(400, "Invalid date/time format. Use date=YYYY-MM-DD and time=HH:MM")

    if et <= st:
        raise HTTPException(400, "end_time must be after start_time")

    # rezervarea nu poate fi in trecut
    now = datetime.now()
    booking_start_dt = datetime.combine(d, st)
    if booking_start_dt <= now:
        raise HTTPException(400, "Cannot create booking in the past")

    # verific hold valid
    if not validate_hold(field_id, me.username, hold_token):
        raise HTTPException(403, "You must have a valid hold on the field to create a booking (or hold expired)")
    
    # mutex DB pe (field_id, date) pentru a preveni double booking in caz de request-uri concurente
    db.execute(
        text("SELECT pg_advisory_xact_lock(:k1, :k2)"),
        {"k1": field_id, "k2": d.toordinal()} # combinatie unica field_id + date
    )
    # acum am lock pe (field_id, date) pana se termina tranzactia curenta

    # verific sa nu existe overlap cu alta rezervare activa pe acelasi teren, in aceeasi zi
    existing = db.query(Booking).filter(
        Booking.field_id == field_id,
        Booking.date == d,
        Booking.status == "active"
    ).all()

    for b in existing:
        if overlaps(st, et, b.start_time, b.end_time):
            raise HTTPException(409, "Field already booked in that time interval")

    # daca nu exista conflict, creez rezervarea
    booking = Booking(
        user_id=me.id,
        field_id=field_id,
        date=d,
        start_time=st,
        end_time=et,
        status="active"
    )

    try:
        db.add(booking)
        db.commit()
        db.refresh(booking)
    except IntegrityError:
        db.rollback()
        cancel_hold(field_id, hold_token) # anulez hold-ul daca nu s-a putut crea rezervarea
        raise HTTPException(400, "Invalid booking data")

    # anulez hold-ul dupa creare rezervare
    cancel_hold(field_id, hold_token)

    # publicare eveniment booking.created in RabbitMQ
    publish_event(
        routing_key="booking.created",
        payload={
            "booking_id": booking.id,
            "field_id": booking.field_id,
            "user_id": booking.user_id,
            "date": str(booking.date),
            "start_time": str(booking.start_time),
            "end_time": str(booking.end_time),
            "status": booking.status
        }
    )

    return {
        "message": "Booking created successfully",
        "booking_id": booking.id,
        "field_id": booking.field_id,
        "user_id": booking.user_id,
        "date": str(booking.date),
        "start_time": str(booking.start_time),
        "end_time": str(booking.end_time),
        "status": booking.status
    }

# listare rezervari curente (status "active")
# user: doar ale lui; admin: toate
@app.get("/bookings/active")
def list_active_bookings(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    me = get_me(db, current_user)

    q = db.query(Booking).filter(Booking.status == "active")
    if me.role != "admin":
        q = q.filter(Booking.user_id == me.id)

    return q.order_by(Booking.id.asc()).all()

# listare rezervari finalizate (status "expired")
# user: doar ale lui; admin: toate
@app.get("/bookings/expired")
def list_expired_bookings(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    me = get_me(db, current_user)

    q = db.query(Booking).filter(Booking.status == "expired")
    if me.role != "admin":
        q = q.filter(Booking.user_id == me.id)

    return q.order_by(Booking.id.asc()).all()

# listare rezervari anulate (status "cancelled")
# user: doar ale lui; admin: toate
@app.get("/bookings/cancelled")
def list_cancelled_bookings(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    me = get_me(db, current_user)

    q = db.query(Booking).filter(Booking.status == "cancelled")
    if me.role != "admin":
        q = q.filter(Booking.user_id == me.id)

    return q.order_by(Booking.id.asc()).all()

# anulare rezervare
# user: doar pe a lui; admin: orice rezervare
@app.post("/bookings/cancel/{booking_id:int}")
def cancel_booking(
    booking_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    me = get_me(db, current_user)

    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(404, "Booking not found")

    # daca nu sunt admin, trebuie sa fie booking-ul meu
    if me.role != "admin" and booking.user_id != me.id:
        raise HTTPException(403, "Not allowed")

    if booking.status != "active":
        raise HTTPException(400, "Only active bookings can be cancelled")

    booking.status = "cancelled"
    db.commit()
    db.refresh(booking)

    return {
        "message": "Booking cancelled successfully",
        "booking_id": booking.id,
        "status": booking.status
    }