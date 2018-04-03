#!/bin/bash
yum makecache fast -y
yum install varnish -y
systemctl stop varnish

cat<<EOF>/etc/varnish/default.vcl
vcl 4.0;
import directors;

acl purge {
    "localhost";
    "10.11.12.0"/24;
}

backend scalaAPPlb {
    .host = "10.11.12.20";
    .port = "80";
        .probe = {
        .url = "/status";
        .expected_response = 200;
        .timeout = 20s;
        .interval = 5s;
        .window = 3;
        .threshold = 2;
    }
}

sub vcl_init {
        new scalaAPP = directors.round_robin();
        scalaAPP.add_backend(scalaAPPlb);
}

sub vcl_recv {

  if (req.method == "BAN") {
          if (!client.ip ~ purge) {
                  return(synth(403, "Not allowed."));
          }
          ban("req.http.host == " + req.http.host +
                " && req.url == " + req.url);
          return(synth(200, "Ban added"));
  }

   unset req.http.Cookie;
   if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "DELETE") {
        return (pipe);
    }

    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    if (req.url ~ "/admin") {
        return(pass);
    }
}


sub vcl_deliver {
        unset resp.http.X-Varnish;
        unset resp.http.X-Cache-Status;
        unset resp.http.Server;
        unset resp.http.Via;
        unset resp.http.Age;
}
EOF

cat<<EOF>/etc/varnish/varnish.params
RELOAD_VCL=1
VARNISH_VCL_CONF=/etc/varnish/default.vcl
VARNISH_LISTEN_ADDRESS=0.0.0.0
VARNISH_LISTEN_PORT=80
VARNISH_ADMIN_LISTEN_ADDRESS=127.0.0.1
VARNISH_ADMIN_LISTEN_PORT=6082
VARNISH_SECRET_FILE=/etc/varnish/secret
VARNISH_STORAGE="malloc,2G"
VARNISH_TTL=3600
VARNISH_USER=varnish
VARNISH_GROUP=varnish
EOF

systemctl start varnish
systemctl enable varnish
