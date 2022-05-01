FROM ubuntu:18.04 AS builder

ENV NGINX_GIT_SHA=285a495 \
    NGINX_BUILD_ROOT_DIR=/opt/nginx \
    SITE_URL="let.me.play" \
    LUAJIT_VER=v2.1-20220411 \
    LUAJIT_DEVELKIT_VER=v0.3.1 \
    LUAJIT_NGINXMOD_VER=v0.10.20 \
    LUAJIT_LIB=/opt/nginx/usr/local/lib \
    LUAJIT_INC=/opt/nginx/usr/local/include/luajit-2.1 \
    LUA_RESTY_VER=v0.1.22 \
    LUA_LRU_VER=v0.11

WORKDIR /tmp

# Install prerequisites for Nginx compile
RUN apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
     ca-certificates wget make gcc pkg-config git libssl-dev zlib1g-dev libpcre++-dev

# Make dirs
RUN mkdir -p ${NGINX_BUILD_ROOT_DIR}/usr/local \
    && mkdir -p ${NGINX_BUILD_ROOT_DIR}/opt/vay

# Download Nginx and Nginx modules source
RUN git clone https://github.com/nginx/nginx.git nginx \
    && cd /tmp/nginx \
    && git checkout ${NGINX_GIT_SHA}

# install luajit
RUN wget -O luajit2.tar.gz https://github.com/openresty/luajit2/archive/refs/tags/${LUAJIT_VER}.tar.gz \
    && mkdir luajit2 \
    && tar -zxf luajit2.tar.gz -C luajit2 --strip-components=1 \
    && cd luajit2 \
    && make PREFIX=${NGINX_BUILD_ROOT_DIR}/usr/local \
    && make install PREFIX=${NGINX_BUILD_ROOT_DIR}/usr/local

# download lua nginx modules
RUN wget -O nginx.dev.tar.gz https://github.com/simpl/ngx_devel_kit/archive/${LUAJIT_DEVELKIT_VER}.tar.gz \
    && mkdir ngx_devel_kit \
    && tar -zxf nginx.dev.tar.gz -C ngx_devel_kit --strip-components=1
RUN wget -O nginx.lua.tar.gz https://github.com/openresty/lua-nginx-module/archive/${LUAJIT_NGINXMOD_VER}.tar.gz \
    && mkdir lua-nginx-module \
    && tar -zxf nginx.lua.tar.gz -C lua-nginx-module --strip-components=1

# Build Nginx
WORKDIR /tmp/nginx/
RUN  ./auto/configure \
          --prefix=/usr/share/nginx \
          --sbin-path=/usr/sbin/nginx \
          --conf-path=/etc/nginx/nginx.conf \
          --pid-path=/run/nginx.pid \
          --lock-path=/var/lock/nginx.lock \
          --error-log-path=/var/log/nginx/error.log \
          --http-log-path=/var/log/nginx/access.log \
          --with-threads \
          --with-http_ssl_module \
          --with-http_v2_module \
          --with-file-aio \
          --with-select_module \
          --without-poll_module \
          --with-http_sub_module \
          --add-module=/tmp/ngx_devel_kit \
          --add-module=/tmp/lua-nginx-module &&\
    make -j$(nproc) &&\
    make DESTDIR=${NGINX_BUILD_ROOT_DIR} install && \
    cp /proc/loadavg /proc/sys/kernel/random/entropy_avail ${NGINX_BUILD_ROOT_DIR}/opt/vay

RUN wget -O lua-resty-core.tar.gz https://github.com/openresty/lua-resty-core/archive/${LUA_RESTY_VER}.tar.gz \
    && mkdir lua-resty-core \
    && tar -zxf lua-resty-core.tar.gz -C lua-resty-core --strip-components=1 \
    && cd lua-resty-core \
    && make install PREFIX=${NGINX_BUILD_ROOT_DIR}/usr/local

RUN wget -O lua-resty-lrucache.tar.gz https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/${LUA_LRU_VER}.tar.gz \
    && mkdir lua-resty-lrucache \
    && tar -zxf lua-resty-lrucache.tar.gz -C lua-resty-lrucache --strip-components=1 \
    && cd lua-resty-lrucache \
    && make install PREFIX=${NGINX_BUILD_ROOT_DIR}/usr/local

RUN mkdir -p ${NGINX_BUILD_ROOT_DIR}/etc/ssl/ \
     && openssl req -x509 -nodes -days 365 \
     -subj "/C=CA/ST=QC/O=Company Inc/CN=${SITE_URL}" \
     -newkey rsa:2048 -keyout ${NGINX_BUILD_ROOT_DIR}/etc/ssl/nginx-selfsigned.key \
     -out ${NGINX_BUILD_ROOT_DIR}/etc/ssl/nginx-selfsigned.crt

RUN openssl x509 -in ${NGINX_BUILD_ROOT_DIR}/etc/ssl/nginx-selfsigned.crt -text -nocert -out ${NGINX_BUILD_ROOT_DIR}/opt/vay/ssl.txt

COPY ./Dockerfile ${NGINX_BUILD_ROOT_DIR}/opt/vay

COPY ./nginx.conf ${NGINX_BUILD_ROOT_DIR}/etc/nginx/
   
FROM ubuntu:18.04

LABEL maintainer="mike.goltsov@gmail.com"

ENV NGINX_USER=www-data \
    NGINX_SITECONF_DIR=/etc/nginx/sites-enabled \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/lib/nginx \
    LD_LIBRARY_PATH=/usr/local/lib

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      libssl1.1 usbutils pciutils\
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/nginx /

EXPOSE 80/tcp 443/tcp

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
