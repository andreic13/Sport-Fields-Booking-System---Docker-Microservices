#!/bin/bash


docker stack rm scd

sleep 2

docker build -t fields-service-img ./fields-service

sleep 10

docker stack deploy -c stack.yml scd

echo "Done!"
