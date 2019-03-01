FROM ubuntu:16.04

ENV GO_VERSION=1.12
ENV NGINX_VERSION 1.14.2

RUN apt-get update && apt-get install -y \
  python \
  python3 \
  build-essential \
  curl \
  gcc-5 \
  g++-5 \
  linux-tools-common \
  linux-tools-generic \
  libssl-dev \
  libpcre3-dev \
  libnss3-tools \
  git \
 && rm -rf /var/lib/apt/lists/* \
 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 800 --slave /usr/bin/g++ g++ /usr/bin/g++-5 \
 && rm -rf /usr/local/lib/python3.6

RUN curl https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
 && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
 && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
 && export GNUPGHOME="$(mktemp -d)" \
 && found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $GPG_KEYS from $server"; \
    gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
 && rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
 && mkdir -p /usr/src \
 && tar -zxC /usr/src -f nginx.tar.gz \
 && rm nginx.tar.gz; \
  CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-file-aio \
    --with-http_v2_module \
  " \
 && cd /usr/src/nginx-$NGINX_VERSION \
 && ./configure $CONFIG --with-debug --with-cc-opt='-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIC' --with-ld-opt='-fPIE -pie -Wl,-z,relro -Wl,-z,now' \
 && make -j$(getconf _NPROCESSORS_ONLN) \
 && mv objs/nginx objs/nginx-debug \
 && ./configure $CONFIG  --with-cc-opt='-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIC' --with-ld-opt='-fPIE -pie -Wl,-z,relro -Wl,-z,now' \
 && make -j$(getconf _NPROCESSORS_ONLN) \
 && make install \
 && rm -rf /etc/nginx/html/ \
 && mkdir /etc/nginx/conf.d/ \
 && mkdir -p /usr/share/nginx/html/ \
 && install -m644 html/index.html /usr/share/nginx/html/ \
 && install -m644 html/50x.html /usr/share/nginx/html/ \
 && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
 && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
 && rm -rf /usr/src/nginx-$NGINX_VERSION \
 && addgroup --system nginx \
 && adduser --system --home /var/cache/nginx --shell /sbin/nologin --gid "$(cat /etc/group | grep nginx | cut -d ':' -f 3)" nginx

RUN dd if=/dev/urandom bs=1 count=80 >/etc/nginx/ticket.key \
 && chmod 400 /etc/nginx/ticket.key

RUN openssl dhparam -out /etc/nginx/dhparams.1024.pem 1024

ENV PATH="$PATH:/usr/local/go/bin"
ENV GOROOT="/usr/local/go"
ENV GOPATH="/"

RUN go get -u github.com/FiloSottile/mkcert \
 && mkcert -install \
 && mkcert -cert-file /etc/nginx/nginx.crt -key-file /etc/nginx/nginx.key server.test localhost 127.0.0.1 ::1 \
 && mkcert -cert-file /etc/client.crt -key-file /etc/client.key client.test localhost 127.0.0.1 ::1


COPY nginx.conf /etc/nginx/nginx.conf

COPY run.sh /run.sh

CMD [ "/run.sh" ]
