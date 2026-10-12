#!/bin/bash


docker stack rm scd

sleep 2

docker build -t expirer-worker-img ./expirer-worker

sleep 10

docker stack deploy -c stack.yml scd

echo "Done!"
