#FROM frolvlad/alpine-glibc
FROM ubuntu:22.04 as build

SHELL ["/bin/bash", "-x", "-c", "-o", "pipefail"]

ARG RUN DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV home_path="/root"

RUN apt update && apt install -y  \
        ca-certificates \
        dumb-init \
        tzdata \
		gnupg \
		curl \
		wget \
		lsb-core \
		software-properties-common \
  && update-ca-certificates

RUN apt update && apt -y install unzip wget

WORKDIR /tmp

#Install Spin
ARG spin_version=v0.8.0
RUN curl -sLO https://github.com/fermyon/spin/releases/download/${spin_version}/spin-${spin_version}-linux-amd64.tar.gz \
	&& tar zxvf spin-${spin_version}-linux-amd64.tar.gz -C /usr/local/bin \
	&& chmod +x /usr/local/bin/spin

#Install Bindle
ARG bindle_version=v0.8.0
RUN curl -sO https://bindle.blob.core.windows.net/releases/bindle-${bindle_version}-linux-amd64.tar.gz \
	&& tar zxvf bindle-${bindle_version}-linux-amd64.tar.gz -C /usr/local/bin \
	&& chmod +x /usr/local/bin/bindle*

#Install Hippo
ARG hippo_version=v0.19.1
RUN curl -sLO https://github.com/deislabs/hippo/releases/download/${hippo_version}/hippo-server-linux-x64.tar.gz \
 	&& mkdir -p ${home_path}/hippo \
 	&& tar zxvf hippo-server-linux-x64.tar.gz -C ${home_path}/hippo \
 	&& chmod +x ${home_path}/hippo/linux-x64/Hippo.Web

#Apply Fermyon styling to Hippo
RUN curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/styles.css \
	&& curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/logo.svg \
	&& curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/config.json \
	&& curl -sLO https://www.fermyon.com/favicon.ico \
	&& mv styles.css ${home_path}/hippo/linux-x64/wwwroot/ \
	&& mv config.json favicon.ico logo.svg ${home_path}/hippo/linux-x64/wwwroot/assets/

# Second stage
FROM ubuntu:22.04

ARG RUN DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV home_path="/root"

RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" | tee /etc/apt/sources.list.d/focal-security.list

RUN apt update && apt install -y  \
        ca-certificates \
        dumb-init \
        tzdata \
		gnupg \
		curl \
		wget \
		lsb-core \
		software-properties-common \
		iproute2 \
		libssl1.1 \
  && update-ca-certificates

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AA16FCBCA621E701
RUN apt-add-repository "deb https://apt.releases.hashicorp.com jammy main"

# Install hasicorp dependencies
RUN apt-get update && apt-get install -y nomad consul vault

RUN apt remove -y wget lsb-core software-properties-common gnupg && apt-get clean

COPY --from=build /usr/local/bin/spin /usr/local/bin/spin
COPY --from=build /usr/local/bin/bindle* /usr/local/bin/
COPY --from=build /root /root
ADD ./ /root/
RUN chmod +x "${home_path}/start.sh"
RUN mkdir -p "${home_path}/data"

WORKDIR ${home_path}


EXPOSE 4646 4647 4648 4648/udp 8080 8500 8200 8081 80

ENTRYPOINT [ "/root/start.sh" ]