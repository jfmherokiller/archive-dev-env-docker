#!/usr/bin/env bash
# Set up rsync
# Create a place to store rsync uploads
mkdir -p /home/rsync/uploads/
cat <<'EOM' >/etc/default/rsync
RSYNC_ENABLE=true
RSYNC_OPTS='--port 9873'
RSYNC_NICE=''
EOM

cat <<'EOM' >/etc/rsyncd.conf
[archiveteam]
path = /home/rsync/uploads/
use chroot = yes
max connections = 100
lock file = /var/lock/rsyncd
read only = no
list = yes
uid = rsync
gid = rsync
strict modes = yes
ignore errors = no
ignore nonreadable = yes
transfer logging = no
timeout = 600
refuse options = checksum dry-run
dont compress = *.gz *.tgz *.zip *.z *.rpm *.deb *.iso *.bz2 *.tbz
EOM

# Prefetch megawarc factory
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/" ]; then
	git clone https://github.com/ArchiveTeam/archiveteam-megawarc-factory.git /home/rsync/archiveteam-megawarc-factory/
fi
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/megawarc/" ]; then
    git clone https://github.com/alard/megawarc.git /home/rsync/archiveteam-megawarc-factory/megawarc/
fi

