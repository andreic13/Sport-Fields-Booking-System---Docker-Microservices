#!/bin/bash

CLIENT_ID="scd-client"
CLIENT_SECRET="y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z"
REALM="scd-realm"
KEYCLOAK_URL="http://localhost:8080"
BOOKINGS_SERVICE_URL="http://localhost:8003"

USER="guest"
PASS="guest123"
FIELD_ID=2

echo "=== Notifications test ==="
echo "Creez 2 booking-uri: start +31m (end +32m) si start +32m (end +33m)."
echo "Anulez pe prima ca sa vad: Skipping pt prima + Reminder pt a doua in logs."
echo ""

# calculez data/ora automat
DATE1=$(date -d "+31 minutes" +"%Y-%m-%d")
START1=$(date -d "+31 minutes" +"%H:%M")
END1=$(date -d "+32 minutes" +"%H:%M")

DATE2=$(date -d "+32 minutes" +"%Y-%m-%d")
START2=$(date -d "+32 minutes" +"%H:%M")
END2=$(date -d "+33 minutes" +"%H:%M")

echo "Booking1: $DATE1 $START1-$END1"
echo "Booking2: $DATE2 $START2-$END2"
echo ""

# token
TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=password" \
  -d "username=$USER" \
  -d "password=$PASS" | jq -r .access_token)

echo "Token ok (user=$USER)"
echo ""

# booking 1
HOLD1=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=$FIELD_ID" \
  -H "Authorization: Bearer $TOKEN" | jq -r .hold_token)

RESP1=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=$FIELD_ID&date=$DATE1&start_time=$START1&end_time=$END1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD1\"}")

B1=$(echo "$RESP1" | jq -r .booking_id)

echo "Booking1 created: id=$B1"
echo "$RESP1" | jq
echo ""

# booking 2
HOLD2=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=$FIELD_ID" \
  -H "Authorization: Bearer $TOKEN" | jq -r .hold_token)

RESP2=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=$FIELD_ID&date=$DATE2&start_time=$START2&end_time=$END2" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD2\"}")

B2=$(echo "$RESP2" | jq -r .booking_id)

echo "Booking2 created: id=$B2"
echo "$RESP2" | jq
echo ""

# anulare booking 1 ca sa obtin "Skipping reminder for booking 1"
echo "Cancel Booking1 (id=$B1) ca sa apara 'Skipping reminder'..."
curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/cancel/$B1" \
  -H "Authorization: Bearer $TOKEN" | jq
echo ""
