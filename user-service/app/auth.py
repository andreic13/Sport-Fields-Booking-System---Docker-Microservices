import requests # http requests catre keycloak
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer
from jose import jwt # decode / verificare jwt
from jose.exceptions import JWTError, ExpiredSignatureError # exceptii
import os

# endpoint standard din OIDC
OIDC_URL = os.environ["OIDC_URL"]

# retin cheile publice (jwks) prima data, sa nu le iau la fiecare request
jwks_cache = None

# functie apelabila care ia tokenul din header
oauth2_call = HTTPBearer()

def get_jwks():
    # daca am deja jwks, le returnez direct
    global jwks_cache
    if jwks_cache:
        return jwks_cache

    # doar la primul request, extrag jwks si le salvez in cache
    oidc_conf = requests.get(OIDC_URL).json()
    jwks_uri = oidc_conf["jwks_uri"]
    jwks_cache = requests.get(jwks_uri).json()
    return jwks_cache

# decode si verific tokenul
def decode_token(token: str):
    jwks = get_jwks()

    try:
        headers = jwt.get_unverified_header(token) # iau header jwt
        kid = headers.get("kid") # ce key id are cheia publica

        key = next((k for k in jwks["keys"] if k["kid"] == kid), None)
        if not key:
            raise HTTPException(status_code=401, detail="Invalid key ID")

        # iau payload-ul fara verificare
        unverified = jwt.get_unverified_claims(token)

        # decodare + validare
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            options={"verify_aud": False, "verify_iss": False}, # nu verific audience si issuer
        )

        return payload

    except ExpiredSignatureError: # daca semnatura a expirat
        raise HTTPException(status_code=401, detail="Token expired")

    except JWTError: # orice alta eroare de validare
        raise HTTPException(status_code=401, detail="Invalid token")


def get_current_user(token: str = Depends(oauth2_call)):
    payload = decode_token(token.credentials) # decode + verific token

    return {
        "username": payload.get("preferred_username"),
        "email": payload.get("email"),
    }
