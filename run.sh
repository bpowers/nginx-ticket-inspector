#!/bin/bash

(nginx -c /etc/nginx/nginx.conf &)

sleep 1

curl --cert /etc/client.crt --key /etc/client.key -v https://localhost/

echo | openssl s_client -cert /etc/client.crt -key /etc/client.key -connect localhost:443 -reconnect 2>/dev/null | egrep 'New|Reused'
