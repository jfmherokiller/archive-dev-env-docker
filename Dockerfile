FROM ubuntu:12.04
#ssh,rsync,tracker ports
EXPOSE 9022 8001 9873 9080
ENTRYPOINT /sbin/init
RUN apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
	openssh-server \
	build-essential \
	wget \
	curl \
	rsync \
	screen \
	python \
	python-dev \
	python-pip \
	git \
	lua5.1 \
	liblua5.1-0-dev \
	libssl-dev \
	libgnutls-dev \
	zlib1g-dev \
	npm \
	libyaml-0-2 \
	libcurl4-openssl-dev \
	acpid \
    sudo

#update ssh port and npm
RUN sed -i 's/Port 22/Port 9022/g' /etc/ssh/sshd_config && \
npm install -g npm

ADD new_postinstall.sh /postinstall.sh
RUN /postinstall.sh