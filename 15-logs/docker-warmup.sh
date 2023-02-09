#!/bin/bash

docker pull logstash:8.5.3
docker pull kibana:8.5.3
docker pull elasticsearch:8.5.3

docker save -o ./docker-image/logstash.image logstash:8.5.3
docker save -o ./docker-image/kibana.image kibana:8.5.3
docker save -o ./docker-image/elasticsearch.image elasticsearch:8.5.3
