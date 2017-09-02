FROM ubuntu:12.04
#ssh,rsync,tracker ports
EXPOSE 9022 8001 9873 9080
ENTRYPOINT /sbin/init
#install node and other packages
ADD https://deb.nodesource.com/setup_6.x /tmp/nodeme
RUN bash /tmp/nodeme && apt-get -y install \
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
    sudo \
    nodejs

#set workdir to tmp
#WORKDIR /tmp
ADD . /tmp
#update ssh port
RUN sed -i 's/Port 22/Port 9022/g' /etc/ssh/sshd_config && \



#add users
adduser tracker --disabled-login --gecos "" || \
echo -e "tracker\ntracker" | passwd tracker || \
usermod -a -G tracker tracker || \
usermod -a -G sudo tracker || \
adduser rsync --disabled-login --gecos "" || \
echo -e "rsync\nrsync" | passwd rsync || \
usermod -a -G rsync rsync || \
usermod -a -G sudo rsync  || \

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
echo vm.overcommit_memory=1 >> /etc/sysctl.conf && \
# Install redis
cd /tmp/ && \
wget http://download.redis.io/redis-stable.tar.gz --continue && \
tar xvzf redis-stable.tar.gz && \
cd /tmp/redis-stable && \
make && \
make install && \
cd /tmp/redis-stable/utils && \
echo -e "\n\n\n\n/usr/local/bin/redis-server\n" | ./install_server.sh && \

# Make redis run not as root
chown -R www-data:www-data /var/lib/redis/6379/ && \
chown -R www-data:www-data /var/log/redis_6379.log && \
sed -i "s/\(pidfile *\).*/\1\/var\/run\/shm\/redis_6379.pid/" /etc/redis/6379.conf && \
mv /tmp/redis_6379 /etc/init.d/redis_6379 && \
# Stop redis logs from getting really big
mv /tmp/logrotate_redis /etc/logrotate.d/redis


USER tracker:tracker
# Install nginx with passenger
RUN curl -L get.rvm.io -o /tmp/rvm_stable && \
bash -ex /tmp/rvm_stable --ignore-dotfiles --autolibs=0 --ruby && \
echo "source /home/tracker/.rvm/scripts/rvm" | tee --append /home/tracker/.bashrc /home/tracker/.profile && \
/bin/bash -l -c "rvm requirements" && \
/bin/bash -l -c "rvm install 2.0.0" && \
/bin/bash -l -c "rvm rubygems current" && \
/bin/bash -l -c "gem install bundler --no-ri --no-rdoc" && \
/bin/bash -l -c "gem install rails" && \
/bin/bash -l -c "gem install passenger" && \
/bin/bash -l -c "passenger-install-nginx-module --auto --auto-download --prefix /home/tracker/nginx/" && \

# Set up the nginx config
sed -i "s/\( root *\).*/\1\/home\/tracker\/universal-tracker\/public;passenger_enabled on;/" /home/tracker/nginx/conf/nginx.conf && \
sed -i "s/\( listen *\).*/\19080;/" /home/tracker/nginx/conf/nginx.conf

# Set up the upstart file for nginx
RUN mv /tmp/ngnix-tracker /etc/init/nginx-tracker.conf
# Setup the tracker
RUN git clone https://github.com/ArchiveTeam/universal-tracker.git /home/tracker/universal-tracker/
RUN /bin/bash -l -c "cd /home/tracker/universal-tracker && bundle update cucumber" && \
/bin/bash -l -c "cd /home/tracker/universal-tracker && bundle outdated || :" && \
/bin/bash -l -c "bundle install --gemfile /home/tracker/universal-tracker/Gemfile"
RUN bash -l -c "/tmp/setup_tracker.sh"
# upstart file for tracker websocket



USER rsync:rsync
RUN /tmp/setup_rsync.sh
USER root:root
# Rotate the nginx logs
RUN mv /tmp/rotate-ngix-logs /etc/logrotate.d/nginx-tracker.conf && \
mv /tmp/nodejs_tracker.cnf /etc/init/nodejs-tracker.conf && \
apt-get clean && /bin/bash -l -c "rm /tmp/* --force --recursive || :" && \
echo "Done"