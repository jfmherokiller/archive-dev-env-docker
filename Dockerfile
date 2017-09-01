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
	libyaml-0-2 \
	libcurl4-openssl-dev \
	acpid \
    sudo

#update ssh port
RUN sed -i 's/Port 22/Port 9022/g' /etc/ssh/sshd_config
#install node
RUN curl -sL https://deb.nodesource.com/setup_8.x -o /tmp/nodeinstall && \
sudo -E bash -ex /tmp/nodeinstall && \
sudo apt-get install -y nodejs 

ADD new_postinstall.sh /postinstall.sh
RUN /postinstall.sh