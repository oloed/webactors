coffee = require "coffee-script"
fs     = require "fs"
jsmin  = require("jsmin").jsmin
sys    = require "sys"
http   = require "http"
url    = require "url"

binding = process.binding('net')

ENOENT = binding.ENOENT
getsockname = binding.getsockname

coffeefiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.coffee$/.test f

jsfiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.js$/.test f

task "build", "Build distributable files.", ->
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

read_file_content = (path, cb) ->
  fs.readFile path, cb

transcode_coffeescript = (path, cb) ->
  idx = path.search(/\.js$/)
  if idx is -1
    err = new Error("#{path}: No such file or directory")
    err.errno = ENOENT
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
          error_message = String(e)
          error_string = JSON.stringify(error_message)
          js_script = "console.error(#{error_string})"
        cb(null, new Buffer(js_script, "utf8"))
    
get_content = (path, cb) ->
  read_file_content path, (err, data) ->
    if err and err.errno is ENOENT
      transcode_coffeescript path, cb
    else
      cb(err, data)

task "serve", "Serve yummy specs.", ->
  server = http.createServer (request, response) ->
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
          response.writeHead(404, {'content-type': 'text/plain'})
          response.write("404 Not Found")
        else
          response.writeHead(500, {'content-type': 'text/plain'})
          response.write("500 Internal Server Error\n#{err}")
      else
        headers =
          'content-type': CONTENT_TYPES[ext] or 'text/plain'
          'content-encoding': 'UTF-8'
          'content-length': data.length
        response.writeHead(200, headers)
        unless request.method is "HEAD"
          response.write(data)
      response.end()

  server.listen 0, "localhost", ->
    address = getsockname(server.fd)
    sys.print("Serving at http://localhost:#{address.port}/SpecRunner.html\n")

task "clean", "Clean dirty leftovers.", ->
  files = jsfiles("dist").concat(jsfiles "src").concat jsfiles("spec")
  fs.unlinkSync f for f in files
  fs.rmdirSync "dist"
