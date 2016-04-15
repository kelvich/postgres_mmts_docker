# vim:set ft=dockerfile:
FROM debian:jessie

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN apt-get update \
    && apt-get install -y git \
	&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
	make \
	gcc \
	libreadline-dev \
	bison \
	flex \
	zlib1g-dev \ 
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir /pg
RUN chown postgres:postgres /pg

USER postgres
WORKDIR /pg
ENV CFLAGS -O0
RUN git clone https://github.com/postgrespro/postgres_cluster.git --depth 1
WORKDIR /pg/postgres_cluster
RUN ./configure  --enable-cassert --enable-debug --prefix /usr/local
RUN make -j 4

USER root
RUN make install
RUN cd /pg/postgres_cluster/contrib/pg_tsdtm && make install
RUN cd /pg/postgres_cluster/contrib/raftable && make install
RUN cd /pg/postgres_cluster/contrib/mmts && make install
RUN cd /pg/postgres_cluster/contrib/postgres_fdw && make install

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/local/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh  /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]



