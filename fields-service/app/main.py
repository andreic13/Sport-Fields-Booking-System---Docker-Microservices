from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session

from .database import Base, engine, SessionLocal
from .models import Field, UserProfile
from .auth import get_current_user

from sqlalchemy.exc import IntegrityError

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

@app.get("/")
def root():
    return {"message": "Fields service is running"}

# retunreaza lista tuturor terenurilor (doar nume si sport) folosind baza de date
# ! folosesc get_current_user pentru a ma asigura ca userul este logat
@app.get("/fields")
def list_fields(db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    fields = db.query(Field).all()

    return [
        {
            "id": field.id,
            "name": field.name,
            "sport": field.sport
        }
        for field in fields
    ]

# returneaza detaliile complete ale unui teren folosind baza de date
@app.get("/fields/{field_id}")
def get_field(field_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    field = db.query(Field).filter(Field.id == field_id).first()
    if not field:
        raise HTTPException(404, "Field not found")
    return field

# creeaza un teren nou in baza de date
@app.post("/fields/add")
def create_field(
    name: str,
    location: str,
    sport: str,
    price_per_hour: float,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    require_admin(db, current_user)

    field = Field(
        name=name,
        location=location,
        sport=sport,
        price_per_hour=price_per_hour
    )

    db.add(field)
    db.commit()
    db.refresh(field)
    return field

# actualizeaza un teren existent in baza de date
@app.put("/fields/update/{field_id}")
def update_field(
    field_id: int,
    name: str,
    location: str,
    sport: str,
    price_per_hour: float,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    require_admin(db, current_user)

    field = db.query(Field).filter(Field.id == field_id).first()
    if not field:
        raise HTTPException(404, "Field not found")

    field.name = name
    field.location = location
    field.sport = sport
    field.price_per_hour = price_per_hour

    db.commit()
    db.refresh(field)
    return field

# sterge un teren din baza de date
@app.delete("/fields/delete/{field_id}")
def delete_field(field_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    require_admin(db, current_user)

    field = db.query(Field).filter(Field.id == field_id).first()
    if not field:
        raise HTTPException(404, "Field not found")

    db.delete(field)
    db.commit()
    return {"message": "Field deleted"}