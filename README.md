# lxd-pihole
Script for getting a pihole set up with lxd on Ubuntu

THIS IS INTENDED FOR A FRESH UBUNTU INSTALL, THERE ARE CURRENTLY NO CHECKS FOR EXISTING LXD INSTALL OR CONTAINER NAMES

I haven't thoroughly tested this yet.


```
wget https://raw.githubusercontent.com/Lyamc/lxd-pihole/main/lxd-pihole.sh; chmod +x lxd-pihole.sh; ./lxd-pihole.sh
```

What it does:

Installs LXD, configures pihole container, installs pihole to that container, allows port 53 traffic to and from the container.

If you want to access the web interface, you need a simple proxy to the container IP

Haproxy example: /etc/haproxy/haproxy.conf
Make it so that example.com/pihole --> pi.hole/admin

```
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http
frontend http
    bind *:80 alpn h2
    bind *:443 ssl crt /etc/letsencrypt/blahblah.pem alpn h2
    http-request redirect scheme https unless { ssl_fc }
    mode http
    timeout client 60s
    acl letsencrypt-acl path_beg /.well-known/acme-challenge/
    use_backend letsencrypt-backend if letsencrypt-acl

   acl pihole-acl path_beg -i /pihole
   use_backend pihole-dns if pihole-acl
   
   default_backend rootserver
   
backend rootserver
    timeout connect 10s
    timeout server 10s
    server wwwserver <<<<< webserver ip address goes here >>>>>:80

backend pihole-dns
   reqirep ^([^\ :]*)\ /pihole/(.*)     \1\ /admin/\2
   server pihole <<<<< the pihole container ip address goes here >>>>:80
```

Nginx example: /etc/nginx/sites-available/default
Makes it so that example.com/pihole --> pi.hole/admin
The important bit is the proxy_pass section.

```
server {
        listen 80;
        listen [::]:80;

        # SSL configuration
        #listen 443 ssl;
        #listen [::]:443;

        root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;

        server_name example.com www.example.com;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
                    }
        location /pihole/ {
                proxy_pass http://10.122.146.232/admin/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          }
        
        }

```

