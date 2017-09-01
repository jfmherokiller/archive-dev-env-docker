#!/usr/bin/env bash
# Add service users
adduser tracker --disabled-login --gecos "" || :
echo -e "tracker\ntracker" | passwd tracker

adduser rsync --disabled-login --gecos "" || :
echo -e "rsync\nrsync" | passwd rsync

adduser --system www-data --group --disabled-password --disabled-login --no-create-home || :
