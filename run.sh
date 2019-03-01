#!/bin/bash

(nginx -c /etc/nginx/nginx.conf &)

sleep 1

curl --cert /etc/client.cert --key /etc/client.key -v https://localhost/
