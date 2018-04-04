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
                " && req.url ~ " + req.url);
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

    if (req.url ~ "/check") {
        return(synth(200, "OK"));
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
