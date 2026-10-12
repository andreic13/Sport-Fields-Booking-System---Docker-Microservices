#!/bin/bash

CLIENT_ID="scd-client"
CLIENT_SECRET="y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z"
REALM="scd-realm"
KEYCLOAK_URL="http://localhost:8080"
BOOKINGS_SERVICE_URL="http://localhost:8003"

USER="guest"
PASS="guest123"
FIELD_ID=1

echo "=== Expirer test ==="
echo "Creez un booking scurt: start +1m, end +2m."
echo "Apoi urmaresc expirer-worker sa vad 'Expired 1 bookings.'"
echo ""

DATE=$(date -d "+1 minutes" +"%Y-%m-%d")
START=$(date -d "+1 minutes" +"%H:%M")
END=$(date -d "+2 minutes" +"%H:%M")

echo "Booking: $DATE $START-$END"
echo ""

TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=password" \
  -d "username=$USER" \
  -d "password=$PASS" | jq -r .access_token)

echo "Token ok (user=$USER)"
echo ""

HOLD=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/hold/start?field_id=$FIELD_ID" \
  -H "Authorization: Bearer $TOKEN" | jq -r .hold_token)

RESP=$(curl -s -X POST "$BOOKINGS_SERVICE_URL/bookings/add?field_id=$FIELD_ID&date=$DATE&start_time=$START&end_time=$END" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"hold_token\":\"$HOLD\"}")

BID=$(echo "$RESP" | jq -r .booking_id)

echo "Booking created: id=$BID"
echo "$RESP" | jq
echo ""