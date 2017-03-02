-- a bit tricky here ;)
-- rd

expiration_time = 10*60

function serve_html(cached_page, expiration_time)
  attr = lighty.stat(cached_page)
  --Check if the cached file has expired
  if (attr and (attr['st_mtime'] + expiration_time) > os.time() ) then
    lighty.env["physical.path"] = cached_page
    return true
  else
    print(cached_page .. "not found")
    return false
  end
end

function serve_gzip(cached_page, expiration_time)
  attr = lighty.stat(cached_page .. ".gz")
  --Check if the gziped cached file has expired
  if (attr and  (attr['st_mtime'] + expiration_time) > os.time() ) then
    lighty.header["Content-Encoding"] = "gzip"
    lighty.header["Content-Type"] = ""
    lighty.env["physical.path"] = cached_page .. ".gz"
    return true
  else
    print(cached_page .. "gz not found")
    return false
  end
end

attr = lighty.stat(lighty.env["physical.path"])
if (not attr) then

  lighty.env["physical.rel-path"] = lighty.env["uri.path"]
  --Change the "/opt/apps/wordpress/" to your own wordpress location
  lighty.env["physical.path"] = "/var/www/localhost/htdocs"
                                 .. lighty.env["physical.rel-path"]

  print("DEBUG: "  .. lighty.env["physical.path"])
  -- If we are querying, we don't have to cache of course
  query_condition = not ( lighty.env["uri.query"] and
                          string.find(lighty.env["uri.query"], ".*s=.*"))
  --If there exists a cookie in the client, probably he/she has been here before
  --and has left a comment. In that case we don't use cached content
  --for example, the user might has just submitted a comment.
  user_cookie = lighty.request["Cookie"] or "no_cookie_here"
  cookie_condition = not (string.find(user_cookie, ".*comment_author.*") or
                          string.find(user_cookie, ".*wordpress.*") or
                          string.find(user_cookie, ".*wp-postpass_.*"))

  if (cookie_condition) then
  	print("T " .. user_cookie)
  else 
	print("F " .. user_cookie)
  end
  
-- enable cache for all user
 cookie_condition = true

 if (query_condition and cookie_condition) then
    --construct the full path of the expeted  cached filename for this url
    accept_encoding = lighty.request["Accept-Encoding"] or "no_acceptance"
    cached_page     = lighty.env["physical.doc-root"] ..
                           "/wordpress/wp-content/cache/supercache/" ..
                           lighty.request["Host"] ..
                           lighty.env["request.uri"] ..
                           "/index.html"

    print("CP: " .. cached_page)

    cached_page = string.gsub(cached_page, "index.php/", "/")
    cached_page = string.gsub(cached_page, "//", "/")

    print("CP2: " .. cached_page)

    --If the client accepts gzipped content, send gzipped content
    if (string.find(accept_encoding, "gzip")) then
      --If for some reason the gzipped file does not exist, fallback to the
      --uncompressed cached file
      if not serve_gzip(cached_page, expiration_time) then
      serve_html(cached_page,expiration_time) end
    else
      serve_html(cached_page,expiration_time)
    end
  end
end
