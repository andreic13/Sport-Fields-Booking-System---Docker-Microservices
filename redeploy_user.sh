#!/bin/bash


docker stack rm scd

sleep 2

docker build -t user-service-img ./user-service

sleep 10

docker stack deploy -c stack.yml scd

echo "Done!"
