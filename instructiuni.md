## Rulare:
-> ./restart_stack_and_initsql.sh
-> rulare scripturi + fisiere de inspectare output din /tests

## Script-uri:
-> 3 script-uri pentru reconstruire imagine a serivciilor,
in caz ca fac modificari in cadrul acestora (+ restart stack):
    * redeploy_bookings.sh
    * redeploy_fields.sh
    * redeploy_user.sh
-> script de stergere + start stack daca fac modificari in stack.yml;
(il folosesc si cand vreau sa pornesc stack-ul prima data):
    * start_or_restart_stack.sh
-> pe langa restart stack, sterge volumul de date folosit de serviciile
mele (fara keycloak), anume scd-db-data, pentru a rula din nou init.sql,
in cazul in care fac modificari in baza de date:
    * restart_stack_and_initsql.sh
-> script de rulare a tuturor functionalitatilor pentru Milestone 2,
anume user-service si fields-service:
    * demo_milestone2.sh

## Pornire stack + rulare functionalitati:
./start_or_restart_stack.sh
./demo_milestone2.sh

## Initiere program fara scripturi:
* docker swarm init --advertise-addr 172.25.229.90

* Dupa ce am construit Dockerfile, requirements.txt si main.py minimal pentru fiecare:

docker build -t user-service-img ./user-service
docker build -t fields-service-img ./fields-service
docker build -t bookings-service-img ./bookings-service

* docker stack deploy -c stack.yml scd

## Stergere + Repornire fara scrpituri:
-> Daca vreau sa reinitializez si baza de date:
    * docker volume rm scd_scd-db-data

-> In continuare:
    * docker stack rm scd
    * docker stack deploy -c stack.yml scd

## Servicii:
-> Proprii:
    * user-service → port 8001
    * fields-service → port 8002
    * bookings-service → port 8003
-> Importate:
    * keycloak → port 8080
    * postgres-scd
    * postgres-keycloak
    * redis → 6379
    * rabbitmq → 5672 / 15672

## Credentiale:
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123

KEYCLOAK_USER=admin
KEYCLOAK_PASSWORD=admin123

REALM_NAME=scd-realm


## Exemplu url conectare:
http://172.25.229.90:8001/
->sau, din wsl:
http://localhost:8001/

## Keycloak:
CLIENT=scd-client
CLIENT_SECRET=y33n3lPYXc2Ou8oYec7OFllOd9X0xZ0Z

Users:
    - andrei:andrei123 + andrei@scd.com -> user
    - andreiadmin:andreiadmin123 + andreiadmin@scd.com -> admin
    - guest:guest123 + guest@scd.com -> guest

Test user token:
    POST http://172.25.229.90:8080/realms/scd-realm/protocol/openid-connect/token
    cu BODY:
        client_id=scd-client
        client_secret=CLIENT_SECRET
        grant_type=password
        username=andrei
        password=andrei123

### Retele:

auth-net: servicii <-> keycloak
db-scd-net: servicii <-> postgres-scd
kc-db-net: keycloak <-> postgres-keycloak
mq-net: bookings <-> redis + rabbitmq

### Am facut 2 servicii postgre, unul pentru keycloak, unul pentru serviciile mele, incat, cand stergeam volumul posgtre pentru a se reapela init.sql, se stergeau si datele din keycloak.

### Am adaugat FK la field_id din bookings_table sa nu poata fi creata o rezervare cu field_id inexistent