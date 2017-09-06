FROM phusion/baseimage:0.9.22
#ssh,rsync,tracker ports
EXPOSE 9022 8001 9873 9080 9081
ENTRYPOINT /sbin/my_init
#install node and other packages
ADD https://deb.nodesource.com/setup_6.x /tmp/nodeme
RUN chmod +x /tmp/nodeme && /tmp/nodeme && apt-get -y install \
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
    nodejs \
    libpcre3 \
    libpcre3-dev \
    redis-server

#set workdir to tmp
#WORKDIR /tmp






#enable ssh server
RUN rm -f /etc/service/sshd/down && \
#update ssh port
sed -i 's/Port 22/Port 9022/g' /etc/ssh/sshd_config && \

#add users
useradd -Ums /bin/bash dev && \
useradd -Ums /bin/bash tracker && \
useradd -Ums /bin/bash rsync && \
echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
echo "tracker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
echo "rsync ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \

# Fix dnsmasq bug (see https://github.com/nicolasff/docker-cassandra/issues/8#issuecomment-36922132)
echo 'user=root' >> /etc/dnsmasq.conf

#adduser --system www-data --group --disabled-password --disabled-login --no-create-home

# Install dev libraries
RUN cd /opt/ && \ 
pip install -e "git+https://github.com/ArchiveTeam/seesaw-kit.git#egg=seesaw" && \

# Write info messages
echo $'= ArchiveTeam Developer Environment (\n \l) = \n\
Usernames available: dev, tracker, rsync \n\
Tracker web interface: http://localhost:9080/global-admin/ \n\
Ports: SSH=9022, Rsync=9873' > /etc/issue && \
# Allow redis to take over the memory
sysctl vm.overcommit_memory=1 || \ 
echo vm.overcommit_memory=1 >> /etc/sysctl.conf


# Make redis run not as root
#chown -R www-data:www-data /var/lib/redis/6379/ && \
#chown -R www-data:www-data /var/log/redis_6379.log && \
RUN sed -i "s/\(pidfile *\).*/\1\/var\/run\/shm\/redis_6379.pid/" /etc/redis/redis.conf



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


RUN git clone https://github.com/ArchiveTeam/universal-tracker.git /home/tracker/universal-tracker/ && \
/bin/bash -l -c "cd /home/tracker/universal-tracker && bundle update cucumber" && \
/bin/bash -l -c "cd /home/tracker/universal-tracker && bundle outdated || :" && \
/bin/bash -l -c "bundle install --gemfile /home/tracker/universal-tracker/Gemfile"

#setup nodejs tracker
ADD setup_tracker.sh /tmp
RUN /bin/bash -l -c "/tmp/setup_tracker.sh"

# Set up rsync
USER rsync:rsync

# Create a place to store rsync uploads
RUN mkdir -p /home/rsync/uploads/ && \

# Prefetch megawarc factory
git clone https://github.com/ArchiveTeam/archiveteam-megawarc-factory.git /home/rsync/archiveteam-megawarc-factory/ && \
git clone https://github.com/alard/megawarc.git /home/rsync/archiveteam-megawarc-factory/megawarc/
USER root:root

#move redis serverfiles into place and fix config
ADD redis_server.sh /tmp
ADD logrotate_redis /tmp
RUN mkdir /etc/service/redis && \
mv /tmp/redis_server.sh /etc/service/redis/run && \
sed -i '/daemonize yes/c\daemonize no' /etc/redis/redis.conf && \
# Make redis run not as root
#chown -R www-data:www-data /var/lib/redis/6379/ && \
chown -R www-data:www-data /var/log/redis/ && \

# Stop redis logs from getting really big
mv /tmp/logrotate_redis /etc/logrotate.d/redis && \
#fix redis config perms
chmod 777 /etc/redis/redis.conf

#move rsyncd,rsync runit files into place
ADD rsync_server.sh /tmp
ADD rsyncd.conf /tmp
RUN mkdir /etc/service/rsync && \
mv /tmp/rsync_server.sh /etc/service/rsync/run && \
mv /tmp/rsyncd.conf /etc/rsyncd.conf

# Set up the runit file for nginx
ADD ngnix_server.sh /tmp
RUN mkdir /etc/service/nginx && \
mv /tmp/ngnix_server.sh /etc/service/nginx/run

# Rotate the nginx logs
ADD rotate-ngnix-logs /tmp
RUN mv /tmp/rotate-ngnix-logs /etc/logrotate.d/nginx-tracker.conf

#add nodejs tracker runit
ADD nodejs_server.sh /tmp
RUN mkdir /etc/service/nodejs-tracker && \
mv /tmp/nodejs_server.sh /etc/service/nodejs-tracker/run && \

# Clean up APT when done.
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
echo "Done"