# Sport-Fields-Booking-System---Docker-Microservices

A microservices platform for managing and booking sports fields (football, basketball, tennis, padel, etc.). It provides SSO authentication, role-based access control, field management, and a concurrency-safe booking flow with notifications.
 
## Features
 
**Users can:**
- Sign in with SSO (OAuth via Keycloak)
- View their own profile
- List fields and view field details
- Check a field's availability on a given date
- Book an available field
- Cancel their own active bookings
- List their own bookings by status: `active`, `expired`, `cancelled`
**Admins can additionally:**
- View details of all users
- Manage user roles in PostgreSQL
- Add, update and delete fields
- Cancel any active booking
- View all bookings (`active`, `expired`, `cancelled`)
## Architecture
 
### Core components
 
#### 1. Keycloak (SSO authentication)
- Handles authentication and issues JWT access tokens
- Exposes a JWKS (JSON Web Key Set) endpoint, used by the services to verify token signatures and integrity
- Port: `8080`
#### 2. User profile service (role management)
- Connected to Keycloak for JWT decoding and validation
- Returns the current user, resolved from the token and loaded from PostgreSQL
- Exposes routes to list users and change roles. Only admins (role checked in the database) can change their own or another user's role in the `user_profiles` table
- If a user authenticated through Keycloak is not yet in the database, they are created on the fly with the `user` role
Credentials are stored and validated in Keycloak, which returns the access token. Role management and verification use the application database.
 
#### 3. Databases (PostgreSQL)
- Application database storing `user_profiles` (users and roles), `fields` and `bookings`
- A separate PostgreSQL instance storing Keycloak data (realm, user credentials)
- The application database is accessed directly by the internal services only
#### 4. Fields service
- CRUD API for sports fields, backed by a PostgreSQL table
- Authenticated users consult it for details before booking
- Access is based on roles stored in PostgreSQL
#### 5. Bookings service
- Creates bookings (with availability checks, future dates only), cancels them, and lists `active` / `expired` / `cancelled` bookings
- A worker checks every 30 seconds and marks finished bookings as `expired` instead of deleting them, preserving history
- Communicates with RabbitMQ (notification worker) and Redis (distributed mutex)
- Access is based on roles stored in PostgreSQL
### Advanced features
 
#### 6. "Something happened" notifications
Notifications are sent when a booking is successfully created and 30 minutes before a booking starts.
 
- Booking creation publishes an event to a RabbitMQ exchange
- The exchange routes it, by routing key, to a queue
- A worker consumes the queue and prints a "booking created" notification. It then starts a secondary thread that waits until 30 minutes before the booking starts and prints a reminder
- Before printing the reminder, the thread asks the bookings service whether the booking is still active. If it is not, the reminder is skipped (the skip is logged)
#### 7. Distributed mutual exclusion (temporary booking lock)
Before booking a field, a user must start a booking "hold". Without an active hold, a booking cannot be created.
 
1. The user starts a hold
2. A temporary lock is placed on that field for all other users (TTL: 3 minutes)
3. The lock is released if the user completes the booking, cancels the hold, or the TTL expires
4. Only one user can hold a given field at any time
Implemented with Redis + TTL. This prevents double booking.
 
## API
 
### Users
| Method | Endpoint | Description | Access |
|---|---|---|---|
| GET | `/users/me` | Own profile | user |
| GET | `/users` | List all users | admin |
| PUT | `/users/{id}?new_role=<role>` | Change a user's role | admin |
 
### Fields
| Method | Endpoint | Description | Access |
|---|---|---|---|
| GET | `/fields` | List fields (name, sport type, id) | user |
| GET | `/fields/{id}` | Full field info (price, location) | user |
| POST | `/fields/add?name=&location=&sport=&price_per_hour=` | Add a field | admin |
| PUT | `/fields/update/{id}?name=&location=&sport=&price_per_hour=` | Update a field | admin |
| DELETE | `/fields/delete/{id}` | Delete a field | admin |
 
### Bookings
| Method | Endpoint | Description | Access |
|---|---|---|---|
| GET | `/bookings/availability/{field_id}?date=yyyy-mm-dd` | Availability on a date | user |
| POST | `/bookings/hold/start?field_id=` | Create a Redis hold (TTL 180 s) and return a `hold_token`, if the field is not already held | user |
| POST | `/bookings/hold/cancel?field_id=` (body: `hold_token`) | Release the hold if the token is valid | user |
| POST | `/bookings/add?field_id=&date=YYYY-MM-DD&start_time=HH:MM&end_time=HH:MM` | Create a booking. Requires an active hold by the same user on that field | user |
| GET | `/bookings/active` | Active bookings | user / admin |
| GET | `/bookings/expired` | Expired bookings | user / admin |
| GET | `/bookings/cancelled` | Cancelled bookings | user / admin |
| POST | `/bookings/cancel/{booking_id}` | Cancel a booking | user / admin |
 
For the list endpoints, admins see all users' bookings and regular users see only their own. For cancellation, admins can cancel any booking and users only their own.
 
## Replicated component
 
The bookings service runs as **3 instances** for high availability. It is the critical component: it handles concurrent operations (booking creation) that may be requested simultaneously by many users, or twice by the same user. It is also the only service that uses the advanced features.
 
Race conditions are prevented with two mechanisms:
 
- **Redis hold via Lua script.** The hold is set by a Lua script. Redis runs Lua scripts on a single thread, so two users cannot lock the same field simultaneously.
- **`pg_advisory_xact_lock`.** A database-level mutex. If two booking requests arrive at the same time for the same `(field_id, date)`, only one proceeds. The other waits, then sees the first booking and fails with an overlap error.
Together these guarantee that double booking cannot occur.
 
## REST principles
 
1. **Client-server separation.** Clients talk only to the exposed HTTP endpoints (user, fields and bookings services), with no direct access to the database or internal components (Redis, RabbitMQ, PostgreSQL).
2. **Statelessness.** Each request is independent and carries everything needed to process it (e.g. `GET /users/me`, `POST /bookings/cancel/{id}`).
3. **Correct HTTP methods.** `GET`, `POST`, `PUT` and `DELETE` are used according to REST conventions.
4. **JSON resources.** All responses are JSON, for example:
```json
   {
     "id": 16,
     "field_id": 1,
     "status": "active"
   }
```
5. **Proper HTTP status codes.** `200 OK`, `201 Created`, `400 Bad Request`, `403 Forbidden`, `404 Not Found`, `409 Conflict`.
## Tech stack
 
Keycloak, PostgreSQL, Redis, RabbitMQ, JWT / JWKS, REST APIs.
