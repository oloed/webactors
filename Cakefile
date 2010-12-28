coffee = require "coffee-script"
fs     = require "fs"
jsmin  = require("jsmin").jsmin
sys    = require "sys"
http   = require "http"
url    = require "url"
spawn  = require("child_process").spawn

binding = process.binding('net')

ENOENT = binding.ENOENT
EPERM = binding.EPERM
EACCES = binding.EACCES
getsockname = binding.getsockname

coffeefiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.coffee$/.test f

jsfiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.js$/.test f

task "build", "Build delectable files.", ->
  files = coffeefiles("src")

  compiled = for src in files
    data = fs.readFileSync src, "utf8"
    coffee.compile(data)

  src = compiled.join("\n")

  fs.mkdir "dist", 0755, (err) ->
    fs.writeFile "dist/webactors.js", src, ->
      fs.writeFile "dist/webactors.min.js", jsmin(src)

CONTENT_TYPES =
  html: 'text/html'
  css: 'text/css'
  js: 'text/javascript'

make_posix_error = (message, errno) ->
  err = new Error(message)
  err.errno = errno
  err

read_file_content = (path, cb) ->
  fs.readFile path, cb

transcode_coffeescript = (path, cb) ->
  idx = path.search(/\.js$/)
  if idx is -1
    err = make_posix_error("#{path}: No such file or directory", ENOENT)
    cb(err, null)
  else
    coffee_path = "#{path.substr(0, idx)}.coffee"
    read_file_content coffee_path, (err, data) ->
      if err
        cb(err, null)
      else
        try
          coffee_script = data.toString("utf8")
          js_script = coffee.compile(coffee_script)
        catch e
          error_message = "#{coffee_path}: #{e}"
          error_string = JSON.stringify(error_message)
          js_script = "console.error(#{error_string})"
        cb(null, new Buffer(js_script, "utf8"))
    
get_content = (path, cb) ->
  if path.search(/\.\./) isnt -1 or path.substr(path.length - 1, 1) is "/"
    err = make_posix_error("#{path}: Permission denied", EACCES)
    cb(err, null)
  else
    read_file_content path, (err, data) ->
      if err and err.errno is ENOENT
        transcode_coffeescript path, cb
      else
        cb(err, data)

task "spec", "Serve yummy specs.", ->
  server = http.createServer (request, response) ->
    if request.method isnt "HEAD" and request.method isnt "GET"
      headers =
        'Content-Type': 'text/plain'
        'Accept': 'GET, HEAD'
      response.writeHead(405, headers)
      response.write("405 Method Not Allowed\n")
      response.end()
      return
    path = url.parse(request.url).pathname
    m = /\.([a-z]+)$/.exec(path)
    if m
      ext = m[1]
    else
      ext = ""
    path = ".#{path}"
    get_content path, (err, data) ->
      if err
        if err.errno is ENOENT
          response.writeHead(404, {'Content-Type': 'text/plain'})
          unless request.method is "HEAD"
            response.write("404 Not Found\n")
        if err.errno is EPERM or err.errno is EACCES
          response.writeHead(403, {'Content-Type': 'text/plain'})
          unless request.method is "HEAD"
            response.write("403 Forbidden\n")
        else
          response.writeHead(500, {'Content-Type': 'text/plain'})
          unless request.method is "HEAD"
            response.write("500 Internal Server Error\n#{err}\n")
      else
        headers =
          'Content-Type': CONTENT_TYPES[ext] or 'text/plain'
          'Content-Encoding': 'UTF-8'
          'Content-Length': data.length
        response.writeHead(200, headers)
        unless request.method is "HEAD"
          response.write(data)
      response.end()

  server.listen 0, "localhost", ->
    address = getsockname(server.fd)
    spec_url = "http://localhost:#{address.port}/SpecRunner.html"
    sys.print("Serving at #{spec_url}\n")
    spawn('xdg-open', [spec_url])

task "clean", "Clean dirty leftovers.", ->
  files = jsfiles("dist").concat(jsfiles "src").concat jsfiles("spec")
  fs.unlinkSync f for f in files
  fs.rmdirSync "dist"
