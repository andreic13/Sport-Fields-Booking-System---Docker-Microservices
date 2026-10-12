import json
import os
import time
import threading
import pika
import requests # fac request la bookings-service
from datetime import datetime, timedelta

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "admin")

BOOKINGS_URL = os.environ["BOOKINGS_URL"]
INTERNAL_TOKEN = os.getenv("INTERNAL_TOKEN", "secret123")

EXCHANGE = "bookings.events"
# coada efectiva de unde worker-ul preia mesajele
QUEUE_CREATED = "notifications.created"

MINUTES_UNTIL_START_REMINDER = 30

# helper: verifica daca o rezervare e inca activa
def is_booking_active(booking_id: int) -> bool:
    try:
        headers = {"token": INTERNAL_TOKEN}
        resp = requests.get(f"{BOOKINGS_URL}/internal/bookings/{booking_id}", headers=headers, timeout=5)

        if resp.status_code != 200:
            print(f"Error checking booking {booking_id}. Active status: {resp.status_code} {resp.text}", flush=True)
            return False

        data = resp.json()
        return data.get("is_active", False)
    except Exception as e:
        print(f"Exception checking booking {booking_id}: {e}", flush=True)
        return False

# helper: parseaza data si ora din string in datetime
# (accepta ambele formate cu si fara secunde)
def parse_start_dt(date_str: str, time_str: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(f"{date_str} {time_str}", fmt)
        except ValueError:
            pass
    raise ValueError(f"Invalid date/time format: {date_str} {time_str}")

# daca RabbitMQ nu e up cand worker-ul porneste, astept si re-incerc
def connect_rabbitmq():
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)

    while True:
        try:
            return pika.BlockingConnection(
                pika.ConnectionParameters(host=RABBITMQ_HOST, port=RABBITMQ_PORT, credentials=credentials)
            )
        except Exception as e:
            print(f"RabbitMQ not ready, retry in 2s... ({e})", flush=True)
            time.sleep(2)

def schedule_reminder(msg: dict):
    # data la care incepe rezervarea
    start_booking_dt = parse_start_dt(msg['date'], msg['start_time'])

    # cand sa trimit reminder-ul
    remind_time = start_booking_dt - timedelta(minutes=MINUTES_UNTIL_START_REMINDER)
    # acum
    now = datetime.now()

    delay = (remind_time - now).total_seconds()

    # daca timpul pana la reminder a trecut, trimite
    if delay < 0:
        delay = 0
    
    def _run():
        time.sleep(delay)

        # daca nu mai e activa rezervarea, nu trimit reminder
        if not is_booking_active(msg['booking_id']):
            print(
                f"Skipping reminder for booking {msg['booking_id']}, no longer active.",
                flush=True
            )
            return
        
        print(
            f"Reminder! Booking {msg['booking_id']} for field {msg['field_id']} "
            f"starts at {msg['date']} {msg['start_time']}!",
            flush=True
        )

    # rulez reminder-ul in thread secundar
    threading.Thread(target=_run, daemon=True).start()

def on_created(ch, method, properties, body: bytes):
    msg = json.loads(body.decode("utf-8"))

    print(
        f"Done! Booking {msg['booking_id']} created: user={msg['user_id']} "
        f"field={msg['field_id']} date={msg['date']} {msg['start_time']}-{msg['end_time']}",
        flush=True
    )

    # cand o rezervare e creata, programez si reminder-ul
    schedule_reminder(msg)

    # obligatoriu ack la canal ca sa nu se re-livreze mesajul
    ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    connection = connect_rabbitmq()
    channel = connection.channel()

    channel.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)
    channel.queue_declare(queue=QUEUE_CREATED, durable=True)

    # leg coada de exchange pe routing_key specific
    channel.queue_bind(queue=QUEUE_CREATED, exchange=EXCHANGE, routing_key="booking.created")

    channel.basic_qos(prefetch_count=1) # un mesaj o data

    # la consumarea unui mesaj, apelez on_created
    channel.basic_consume(queue=QUEUE_CREATED, on_message_callback=on_created)

    print("Notifications-worker started. Waiting for events...", flush=True)
    channel.start_consuming() # start consumarea mesajelor

if __name__ == "__main__":
    main()
