#!/bin/bash

CLIENT_ID="scd-client"
CLIENT_SECRET="y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z"
REALM="scd-realm"
KEYCLOAK_URL="http://localhost:8080"
USER_SERVICE_URL="http://localhost:8001"
FIELDS_SERVICE_URL="http://localhost:8002"
BOOKINGS_SERVICE_URL="http://localhost:8003"

echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                             Testare User Service\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

echo -e "=============Test GET /users/me cu utilizator neautentificat (astept eroare)=============\n"
curl -X GET "$USER_SERVICE_URL/users/me"
echo -e "\n"

echo -e "=============Login cu andrei/andrei123 (user)=============\n"
TOKEN_ANDREI=$(curl -s -X POST "$KEYCLOAK_URL/realms/scd-realm/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=scd-client" \
    -d "client_secret=y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z" \
    -d "grant_type=password" \
    -d "username=andrei" \
    -d "password=andrei123" | jq -r .access_token)

echo "Token ANDREI setat."
echo "TOKEN_ANDREI: $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test GET /users/me cu token ANDREI (astept date user)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users/me" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test GET /users sa afisez utilizatorii cu token ANDREI (astept eroare deoarece nu e admin)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Login cu andreiadmin/andreiadmin123 (admin)=============\n"
TOKEN_ANDREIADMIN=$(curl -s -X POST "$KEYCLOAK_URL/realms/scd-realm/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=scd-client" \
    -d "client_secret=y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z" \
    -d "grant_type=password" \
    -d "username=andreiadmin" \
    -d "password=andreiadmin123" | jq -r .access_token)

echo "Token ANDREIADMIN setat."
echo "TOKEN_ANDREIADMIN: $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Test GET /users sa afisez utilizatorii cu token ANDREIADMIN (astept lista useri)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Test PUT /users/1 cu token ANDREIADMIN => admin schimba rolul lui andrei la 'admin'=============\n"
curl -s -X PUT "$USER_SERVICE_URL/users/1?new_role=admin" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Utilizatorii devin============="
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Acum utilizatorul ANDREI incearca sa acceseze GET /users (astept lista useri)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e '=============Utilizatorul ANDREI isi schimba rolul inapoi la "user"=============\n'
curl -s -X PUT "$USER_SERVICE_URL/users/1?new_role=user" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Utilizatorul ANDREI incearca sa acceseze GET /users (astept eroare)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Login cu guest/guest123 (user din Keycloak, NU exista in DB)=============\n"
TOKEN_GUEST=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=password" \
  -d "username=guest" \
  -d "password=guest123" | jq -r .access_token)

echo "Token GUEST setat."
echo "TOKEN_GUEST: $TOKEN_GUEST"
echo -e "\n"

echo -e "=============Test GET /users/me cu token GUEST (astept: user creat automat in DB cu rol default=user)=============\n"
curl -s -X GET "$USER_SERVICE_URL/users/me" \
  -H "Authorization: Bearer $TOKEN_GUEST"
echo -e "\n"

echo -e "=============Lista utilizatori finala=============\n"
curl -s -X GET "$USER_SERVICE_URL/users" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                             Testare Fields Service\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

echo -e "=============Test GET /fields sa afisez terenurile cu utilizator neautentificat (astept eroare)=============\n"
curl -X GET "$FIELDS_SERVICE_URL/fields"
echo -e "\n"

echo -e "=============Test GET /fields sa afisez terenurile cu token ANDREI (astept lista terenuri)=============\n"
curl -s -X GET "$FIELDS_SERVICE_URL/fields" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test GET /fields/1 sa afisez detaliile primului teren, inclusiv pretul cu token ANDREI (astept date teren)=============\n"
curl -s -X GET "$FIELDS_SERVICE_URL/fields/1" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test POST /fields sa adaug un teren nou cu token ANDREI (astept eroare deoarece nu e admin)=============\n"
curl -s -X POST "$FIELDS_SERVICE_URL/fields/add?name=TerenUser&location=Timisoara&sport=Fotbal&price_per_hour=200" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test POST /fields sa adaug un teren nou cu token ANDREIADMIN (astept succes)=============\n"
curl -s -X POST "$FIELDS_SERVICE_URL/fields/add?name=TerenAdmin&location=Cluj&sport=Baschet&price_per_hour=300" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Lista terenuri dupa adaugare=============\n"
curl -s -X GET "$FIELDS_SERVICE_URL/fields" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============Test PUT /fields/1 sa modific primul teren cu token ANDREIADMIN (astept succes)=============\n"
curl -s -X PUT "$FIELDS_SERVICE_URL/fields/update/1?name=TerenModificat&location=Bucuresti&sport=Tenis&price_per_hour=150" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Test DELETE /fields/8 sa sterg terenul adaugat anterior cu token ANDREIADMIN (astept succes)=============\n"
curl -s -X DELETE "$FIELDS_SERVICE_URL/fields/delete/8" \
     -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============Lista terenuri finala=============\n"
curl -s -X GET "$FIELDS_SERVICE_URL/fields" \
     -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                             Testare Bookings Service\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

# --Test fara autentificare
echo -e "=============Test GET /bookings/active fara token (astept eroare)=============\n"
curl -i -X GET "$BOOKINGS_SERVICE_URL/bookings/active"
echo -e "\n"

# --Availability
echo -e "=============Test GET /bookings/availability/2?date=2026-01-22 cu token ANDREI (astept busy_intervals)=============\n"
curl -s -X GET "$BOOKINGS_SERVICE_URL/bookings/availability/2?date=2026-01-22" \
  -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

# --Validari create booking
echo -e "\n"
echo -e "*************Testare validari creare rezervare /bookings/add***************\n"
echo -e "\n"

# - End time < start time
echo -e "=============Test POST /bookings/add cu end_time < start_time (astept eroare)=============\n"
# HOLD_BAD pentru a testa validarea
HOLD_BAD=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=1" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=1&date=2026-01-28&start_time=10:00&end_time=09:00" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_BAD\"}"
echo -e "\n"

echo -e "=============Anulez hold-ul (curatenie)=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/cancel?field_id=1" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_BAD\"}"
echo -e "\n"

# - Booking in trecut
echo -e "=============Test POST /bookings/add in trecut (astept eroare)=============\n"
HOLD_PAST=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=1" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=1&date=2025-01-01&start_time=10:00&end_time=11:00" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_PAST\"}"
echo -e "\n"

echo -e "=============Anulez hold-ul (curatenie)=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/cancel?field_id=1" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_PAST\"}"
echo -e "\n"

# - Overlapp cu alta rezervare
echo -e "=============TEST OVERLAP: incerc sa creez booking peste rezervarea gasita activa la field 2 (astept eroare)=============\n"
HOLD_OVER=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=2" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=2&date=2026-01-22&start_time=10:15&end_time=11:30" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_OVER\"}"
echo -e "\n"

echo -e "=============Curatenie: anulez hold=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/cancel?field_id=2" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_OVER\"}"
echo -e "\n"

# -Field id inexistent
echo -e "=============Test POST /bookings/add pe field_id inexistent (120) (astept eroare (FK) + eliverare HOLD)=============\n"
HOLD_120=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=120" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

echo "hold_token pentru field 120: $HOLD_120"
echo -e "\n"

curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=120&date=2026-01-28&start_time=10:00&end_time=11:00" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_120\"}"
echo -e "\n"

# - Rezervare fara hold
echo -e "=============Test POST /bookings/add fara hold valid (astept eroare)=============\n"
curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=1&date=2026-01-28&start_time=10:00&end_time=11:00" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"fake_token\"}"
echo -e "\n"

echo -e "\n"
echo -e "*************Testare validari anulare rezervare /bookings/cancel/{bookings_id}***************\n"
echo -e "\n"

echo -e "=============User GUEST incearca sa anuleze booking-ul 16, al utilizatorului ANDREI (astept eroare)=============\n"
curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/cancel/16" \
  -H "Authorization: Bearer $TOKEN_GUEST"
echo -e "\n"

echo -e "=============User ANDREI anuleaza booking-ul propriu 16 (astept succes)=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/cancel/16" \
  -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============User ANDREI incearca sa anuleze din nou booking-ul 16 (astept eroare)=============\n"
curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/cancel/16" \
  -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "\n"
echo -e "*************Listari active/expired/canceled /bookings/{status}***************\n"
echo -e "\n"

echo -e "=============GET /bookings/active cu ANDREI (astept doar ale lui)=============\n"
curl -s -X GET "$BOOKINGS_SERVICE_URL/bookings/active" -H "Authorization: Bearer $TOKEN_ANDREI"
echo -e "\n"

echo -e "=============GET /bookings/expired cu ANDREIADMIN (astept toate)=============\n"
curl -s -X GET "$BOOKINGS_SERVICE_URL/bookings/expired" -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "=============GET /bookings/cancelled cu ANDREIADMIN (astept toate anulate)=============\n"
curl -s -X GET "$BOOKINGS_SERVICE_URL/bookings/cancelled" -H "Authorization: Bearer $TOKEN_ANDREIADMIN"
echo -e "\n"

echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                                  Hold Mutex\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

echo -e "=============TEST MUTEX REDIS HOLD: user A ia hold, user B primeste eroare=============\n"
echo -e "\n"
echo -e "=============User A incepe hold pe terenul 1 (astept succes)=============\n"
HOLD_A=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=1" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

echo "Hold token user A: $HOLD_A"
echo -e "\n"

echo -e "=============User B incearca hold pe acelasi teren (astept eroare)=============\n"
curl -i -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=1" \
  -H "Authorization: Bearer $TOKEN_GUEST"
echo -e "\n"

echo -e "=============User A finalizeaza booking-ul (astept succes)=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=1&date=2026-01-30&start_time=10:00&end_time=11:00" \
  -H "Authorization: Bearer $TOKEN_ANDREI" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD_A\"}"
echo -e "\n"

echo -e "=============User B incearca din nou hold (astept succes acum)=============\n"
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=1" \
  -H "Authorization: Bearer $TOKEN_GUEST"
echo -e "\n"

echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                                  RabbitMQ Notifications\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

echo -e "=============Testez manual Notifications Worker si Expirer Worker (verific log-urile)=============\n"

# Test Race Conditions
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "                                  Race Conditions\n"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"
echo -e "\n"

echo -e "=============TEST RACE CONDITION 1: 2 hold-uri simultane pentru acelasi teren (astept: 1 succes, 1 eroare)=============\n"

echo -e "Pornesc 2 request-uri /bookings/hold/start in paralel\n"

curl -s -o /tmp/hold1.json -w "CODE1=%{http_code}\n" -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=3" \
  -H "Authorization: Bearer $TOKEN_ANDREI" > /tmp/hold_code1.txt &

curl -s -o /tmp/hold2.json -w "CODE2=%{http_code}\n" -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=3" \
  -H "Authorization: Bearer $TOKEN_GUEST" > /tmp/hold_code2.txt &

wait

echo "Rezultat 1:"
cat /tmp/hold_code1.txt
cat /tmp/hold1.json; echo -e "\n"

echo "Rezultat 2:"
cat /tmp/hold_code2.txt
cat /tmp/hold2.json; echo -e "\n"

echo -e "=============TEST RACE CONDITION 2: 2 request-uri simultane pentru acelasi interval cu acelasi hold (astept: max 1 succes)=============\n"

HOLD_RACE=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=2" \
  -H "Authorization: Bearer $TOKEN_ANDREI" | jq -r .hold_token)

echo "Hold token: $HOLD_RACE"
echo -e "\n"

echo -e "Pornesc 2 request-uri /bookings/add in paralel\n"

curl -s -o /tmp/r1.json -w "CODE1=%{http_code}\n" -X POST \
 "$BOOKINGS_SERVICE_URL/bookings/add?field_id=2&date=2026-02-14&start_time=12:00&end_time=12:10" \
 -H "Authorization: Bearer $TOKEN_ANDREI" -H "Content-Type: application/json" \
 -d "{\"hold_token\":\"$HOLD_RACE\"}" > /tmp/r_code1.txt &

curl -s -o /tmp/r2.json -w "CODE2=%{http_code}\n" -X POST \
 "$BOOKINGS_SERVICE_URL/bookings/add?field_id=2&date=2026-02-14&start_time=12:00&end_time=12:10" \
 -H "Authorization: Bearer $TOKEN_ANDREI" -H "Content-Type: application/json" \
 -d "{\"hold_token\":\"$HOLD_RACE\"}" > /tmp/r_code2.txt &

wait

echo "Rezultat 1:"
cat /tmp/r_code1.txt
cat /tmp/r1.json; echo -e "\n"

echo "Rezultat 2:"
cat /tmp/r_code2.txt
cat /tmp/r2.json; echo -e "\n"