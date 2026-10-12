from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from .database import Base, engine, SessionLocal
from .models import UserProfile
from .auth import get_current_user


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
    return {"message": "User service is running"}

# retunreaza datele userului curent folosind baza de date
@app.get("/users/me")
def get_me(current_user = Depends(get_current_user), db: Session = Depends(get_db)):
    user = create_or_return_user_db(db, current_user)
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "role": user.role
    }


# retunreaza lista tuturor userilor folosind baza de date
@app.get("/users")
def list_users(db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    require_admin(db, current_user) # verifica daca sunt admin

    return db.query(UserProfile).all()

# actualizeaza rolul unui user din baza de date
@app.put("/users/{user_id}")
def update_user_role(user_id: int, new_role: str, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    require_admin(db, current_user) # verifica daca sunt admin

    user = db.query(UserProfile).filter(UserProfile.id == user_id).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.role = new_role
    db.commit()
    db.refresh(user)

    return {
        "message": "User updated successfully",
        "id": user.id,
        "user": user.username,
        "role": user.role
    }