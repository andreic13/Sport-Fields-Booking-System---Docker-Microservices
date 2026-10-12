import json
import os
import pika
import time

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "admin")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", "admin")

# zona in RabbitMQ care trimite mesajele catre cozi pe baza routing_key-ului
EXCHANGE = "bookings.events"

# publica un eveniment in exchange pentru a fi trimis la coada
# safety: retry de 5 ori in caz ca RabbitMQ nu e deja pornit
def publish_event(routing_key: str, payload: dict):
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    for attempt in range(5):
        try:
            # conexiune blocanta la RabbitMQ
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(host=RABBITMQ_HOST, port=RABBITMQ_PORT, credentials=credentials)
            )
            channel = connection.channel() # creare canal de comunicare

            # declarare exchange de tip topic ce persista dupa restart (durable=True)
            channel.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)

            channel.basic_publish(
                exchange=EXCHANGE,
                routing_key=routing_key, # criteriu de filtrare mesaje
                body=json.dumps(payload).encode("utf-8"),
                properties=pika.BasicProperties(
                    content_type="application/json",
                    delivery_mode=2, # persistent
                ),
            )
            connection.close()
            return True
        except Exception as e:
            time.sleep(1)

    # daca MQ nu e disponibil, nu pica booking-ul
    print(f"ERROR! Could not publish event to RabbitMQ after retries", flush=True)
    return False