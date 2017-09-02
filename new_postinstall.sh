#!/usr/bin/env bash




WORKDIR=/tmp/

echo Post VM installing...

cd $WORKDIR




cd $WORKDIR
cat <<'EOM' >/home/tracker/universal-tracker/config/redis.json
{
  "development": {
    "host": "127.0.0.1",
    "port": 6379,
    "db":   13
  },
  "test": {
    "host": "127.0.0.1",
    "port": 6379,
    "db":   14
  },
  "production": {
    "host":"127.0.0.1",
    "port":6379,
    "db": 1
  }
}
EOM
chown tracker:tracker /home/tracker/universal-tracker/config/redis.json

# Fix up tracker
cat <<'EOM' >>/home/tracker/universal-tracker/config.ru
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # We're in smart spawning mode.
    if forked
      # Re-establish redis connection
      redis.client.reconnect
    end
  end
end
EOM
chown tracker:tracker /home/tracker/universal-tracker/config.ru

# Set up tracker websocket
sudo cp -R /home/tracker/universal-tracker/broadcaster /home/tracker/.
cat <<'EOM' >/home/tracker/broadcaster/server.js
var fs = require('fs');
//var env = JSON.parse(fs.readFileSync('/home/dotcloud/environment.json'));

var env = {
    tracker_config: {
        redis_pubsub_channel: "tracker-log"
    },
    redis_db: 1
};

//var trackerConfig = JSON.parse(env['tracker_config']);
var trackerConfig = env['tracker_config'];

var app = require('http').createServer(httpHandler),
    io = require('socket.io').listen(app),
    redis = require('redis').createClient(Number(env['redis_port'] || 6379),
                                          env['redis_host'] || '127.0.0.1',
                                          Number(env['redis_db'] || 0)),
    numberOfClients = 0,
    recentMessages = {};

app.listen(9081);

redis.on("error", function (err) {
  console.log("Error " + err);
});

redis.on("message", redisHandler);

function httpHandler(request, response) {
  var m;
  if (m = request.url.match(/^\/recent\/(.+)/)) {
    var channel = m[1];
    response.writeHead(200, {"Content-Type": "text/plain; charset=UTF-8",
                             'Access-Control-Allow-Origin': '*',
                             'Access-Control-Allow-Credentials': 'true'});
    output = JSON.stringify(recentMessages[channel] || []);
    response.end(output);

  } else {
    response.writeHead(200, {"Content-Type": "text/plain"});
    output = "" + numberOfClients;
    response.end(output);
  }
}

function redisHandler(pubsubChannel, message) {
  console.log(message);
  var msgParsed = JSON.parse(message);
  console.log(msgParsed);
  var channel = msgParsed['log_channel'];
  if (!recentMessages[channel]) {
    recentMessages[channel] = [];
  }
  var msgList = recentMessages[channel];
  msgList.push(msgParsed);
  while (msgList.length > 20) {
    msgList.shift();
  }
  io.of('/'+channel).emit('log_message', message);
}


io.configure(function() {
  io.set("transports", ["websocket", "xhr-polling"]);
  io.set("polling duration", 10);

  var path = require('path');
  var HTTPPolling = require(path.join(
    path.dirname(require.resolve('socket.io')),'lib', 'transports','http-polling')
  );
  var XHRPolling = require(path.join(
    path.dirname(require.resolve('socket.io')),'lib','transports','xhr-polling')
  );

  XHRPolling.prototype.doWrite = function(data) {
    HTTPPolling.prototype.doWrite.call(this);

    var headers = {
      'Content-Type': 'text/plain; charset=UTF-8',
      'Content-Length': (data && Buffer.byteLength(data)) || 0
    };

    if (this.req.headers.origin) {
      headers['Access-Control-Allow-Origin'] = '*';
      if (this.req.headers.cookie) {
        headers['Access-Control-Allow-Credentials'] = 'true';
      }
    }

    this.response.writeHead(200, headers);
    this.response.write(data);
    // this.log.debug(this.name + ' writing', data);
  };
});

io.sockets.on('connection', function(socket) {
  numberOfClients++;
  socket.on('disconnect', function() {
    numberOfClients--;
  });
});


if (env['redis_password']) {
  redis.auth(env['redis_password']);
}
redis.subscribe(trackerConfig['redis_pubsub_channel']);
EOM
chown tracker:tracker /home/tracker/broadcaster/server.js

sudo -i -u tracker npm install socket.io --registry http://registry.npmjs.org/
sudo -i -u tracker npm install redis --registry http://registry.npmjs.org/

# upstart file for tracker websocket
cat <<'EOM' >/etc/init/nodejs-tracker.conf
description "tracker nodejs daemon"

start on runlevel [2]
stop on runlevel [016]

setuid tracker
setgid tracker

exec node /home/tracker/broadcaster/server.js
EOM

# Set up rsync
# Create a place to store rsync uploads
mkdir -p /home/rsync/uploads/
chown rsync:rsync /home/rsync/uploads
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
	sudo -u rsync git clone https://github.com/ArchiveTeam/archiveteam-megawarc-factory.git /home/rsync/archiveteam-megawarc-factory/
fi
if [ ! -d "/home/rsync/archiveteam-megawarc-factory/megawarc/" ]; then
	sudo -u rsync git clone https://github.com/alard/megawarc.git /home/rsync/archiveteam-megawarc-factory/megawarc/
fi

apt-get clean
rm /tmp/* --force --recursive || :

echo Done


