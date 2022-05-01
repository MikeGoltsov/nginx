Testapp with image based on Ubuntu LTS
build nginx with simple template.

1. Clone
```
git clone https://github.com/MikeGoltsov/nginx.git
```

2. Buld
```
cd nginx &&
docker compose build
```

3. Run 
```
docker compose up -d
```

4. To access by name add to /etc/hosts, or, if client on different host - replace 127.0.0.1 to real ip address of docker host
```
127.0.0.1 let.me.play
```

5. Open http://let.me.play:10080 or https://let.me.play:10443  
NOTE: For mitigation the NAT Slipstream 2.0 attack port 10080 blocked by default on most browsers.