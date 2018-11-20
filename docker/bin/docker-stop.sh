#!/usr/bin/env bash

docker stop razor-server
docker stop postgres
docker rm razor-server
docker rm postgres