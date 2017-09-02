#!/usr/bin/env bash
# Set up rsync
# Create a place to store rsync uploads
mkdir -p /home/rsync/uploads/


# Prefetch megawarc factory
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/" ]; then
	git clone https://github.com/ArchiveTeam/archiveteam-megawarc-factory.git /home/rsync/archiveteam-megawarc-factory/
fi
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/megawarc/" ]; then
    git clone https://github.com/alard/megawarc.git /home/rsync/archiveteam-megawarc-factory/megawarc/
fi

