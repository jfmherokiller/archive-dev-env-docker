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

#set workdir to tmp
WORKDIR /tmp

#update ssh port
RUN sed -i 's/Port 22/Port 9022/g' /etc/ssh/sshd_config && \

#install node
sh -c 'curl -sL https://deb.nodesource.com/setup_6.x | bash - ' && \
apt-get install -y nodejs && \

#add users
adduser tracker --disabled-login --gecos "" || \
echo -e "tracker\ntracker" | passwd tracker || \
adduser rsync --disabled-login --gecos "" || \
echo -e "rsync\nrsync" | passwd rsync || \
adduser --system www-data --group --disabled-password --disabled-login --no-create-home || \

# Install dev libraries
cd /opt/ && \ 
pip install -e "git+https://github.com/ArchiveTeam/seesaw-kit.git#egg=seesaw" && \

# Write info messages
echo $'= ArchiveTeam Developer Environment (\n \l) = \n\
Usernames available: dev, tracker, rsync \n\
Tracker web interface: http://localhost:9080/global-admin/ \n\
Ports: SSH=9022, Rsync=9873' > /etc/issue && \
# Allow redis to take over the memory
sysctl vm.overcommit_memory=1 || \ 
echo vm.overcommit_memory=1 >> /etc/sysctl.conf

# Install redis
RUN wget http://download.redis.io/redis-stable.tar.gz --continue && \
tar xvzf redis-stable.tar.gz && \
cd /tmp/redis-stable && \
make && \
make install && \
cd /tmp/redis-stable/utils && \
echo -e "\n\n\n\n/usr/local/bin/redis-server\n" | ./install_server.sh

# Make redis run not as root
RUN chown -R www-data:www-data /var/lib/redis/6379/ && \
chown -R www-data:www-data /var/log/redis_6379.log && \
sed -i "s/\(pidfile *\).*/\1\/var\/run\/shm\/redis_6379.pid/" /etc/redis/6379.conf

ADD redis_6379 /etc/init.d/redis_6379
# Stop redis logs from getting really big
ADD logrotate_redis /etc/logrotate.d/redis

ADD new_postinstall.sh /tmp/postinstall.sh
RUN /tmp/postinstall.sh