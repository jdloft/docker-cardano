ARG NODE=alonzo-blue2.0

# the builder
FROM haskell:8 AS builder

ARG NODE
ARG LIBSODIUM=66f017f1

RUN apt-get update && apt-get install -y automake build-essential pkg-config libffi-dev \
	libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ git jq libncursesw5 libtool autoconf && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /libsodium
RUN git clone https://github.com/input-output-hk/libsodium /libsodium && \
	git checkout ${LIBSODIUM} && \
	./autogen.sh && \
	./configure && \
	make && make install

ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

WORKDIR /app
RUN git clone -b ${NODE} https://github.com/input-output-hk/cardano-node.git /app

RUN cabal update && cabal build all
RUN /bin/sh -c 'mkdir output && mv "$(./scripts/bin-path.sh cardano-node)" output/ && mv "$(./scripts/bin-path.sh cardano-cli)" output/'

# the actual app
FROM debian:buster
LABEL author="Jamison Lofthouse"

ARG NODE

RUN apt-get update && apt-get install -y netbase && \
	rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/libsodium* /usr/local/lib/
COPY --from=builder /usr/local/lib/pkgconfig /usr/local/lib/

ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

WORKDIR /app
COPY --from=builder /app/output/cardano-node .
COPY --from=builder /app/output/cardano-cli .

ENV PATH /app:$PATH

CMD [ "cardano-node" ]
