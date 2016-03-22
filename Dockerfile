## -*- docker-image-name: "docker-crate" -*-
#
# Crate Dockerfile
# https://github.com/crate/docker-crate
#
FROM alpine:latest
MAINTAINER Crate Technology GmbH <office@crate.io>

ENV ANT_VERSION=1.9.6
ENV ANT=/usr/src/apache-ant-${ANT_VERSION}/bin/ant

RUN echo 'http://nl.alpinelinux.org/alpine/latest-stable/community' >> /etc/apk/repositories
RUN set -ex \
    && apk update \
    && apk add -u --no-cache --virtual .build-deps \
    		git gcc libc-dev make cmake libtirpc-dev pax-utils \
        curl openjdk8 gnupg perl \
	  && mkdir -p /usr/src \
	  && cd /usr/src \
    && curl -fSL https://www.apache.org/dist/ant/KEYS -o KEYS \
    && curl -fSL -O https://www.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz.asc \
    && curl -fSL -O http://apache.uib.no//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && gpg --import KEYS \
    && gpg --verify apache-ant-${ANT_VERSION}-bin.tar.gz.asc \
    && tar -zxf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && git clone --branch sigar-1.6.4-musl https://github.com/ncopa/sigar.git \
    && cd sigar/bindings/java \
    && ${ANT} \
    && mkdir -p /usr/local/bin \
	  && find build -name '*.so*' | xargs install -t /usr/local/lib \
	  && runDeps="$( \
		  scanelf --needed --nobanner --recursive /usr/local \
			  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			  | sort -u \
			  | xargs -r apk info --installed \
		  	| sort -u \
	  )" \
  	&& apk add --virtual .libsigar-rundeps $runDeps \
    && apk del .build-deps git gcc libc-dev make cmake libtirpc-dev pax-utils curl openjdk8 gnupg perl \
    && apk add openjdk8-jre-base openssl python3 \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/bin/python3 /usr/bin/python

ENV CRATE_VERSION 0.54.7
RUN wget -O - "https://cdn.crate.io/downloads/releases/crate-$CRATE_VERSION.tar.gz" \
      | tar -xzC / && mv /crate-$CRATE_VERSION /crate \
    && mv -f /usr/src/sigar/bindings/java/sigar-bin/lib/sigar.jar crate/lib/sigar/sigar-1.6.4.jar \
    && mv -f /usr/local/lib/*.so crate/lib/sigar/ \
    && rm -rf /usr/src/*

RUN addgroup crate && adduser -G crate -H crate -D && chown -R crate /crate
ENV PATH /crate/bin:$PATH

VOLUME ["/data"]

ADD config/crate.yml /crate/config/crate.yml
ADD config/logging.yml /crate/config/logging.yml

WORKDIR /data

# http: 4200 tcp
# transport: 4300 tcp
EXPOSE 4200 4300

CMD ["crate"]
