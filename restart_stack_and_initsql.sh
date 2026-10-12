#!/bin/bash

docker stack rm scd

sleep 10

docker volume rm scd_scd-db-data

sleep 10

docker stack deploy -c stack.yml scd

echo "Done!"
