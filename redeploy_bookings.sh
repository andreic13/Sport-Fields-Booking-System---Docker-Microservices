#!/bin/bash


docker stack rm scd

sleep 2

docker build -t bookings-service-img ./bookings-service

sleep 10

docker stack deploy -c stack.yml scd

echo "Done!"
