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
errnoException = binding.errnoException

VERSION = "0.1"
MAINTAINERS = [
  {name: "MenTaLguY", email: "mental@rydia.net", web: "http://moonbase.rydia.net"}]

PACKAGE_SPEC =
  name: "webactors"
  version: VERSION
  description: "WebActors is an implementation of the Actor model for Javascript."
  keywords: ["multicore", "actors", "concurrency"]
  maintainers: MAINTAINERS
  licenses: [{type: "MIT", url: "http://www.opensource.org/licenses/mit-license"}]
  implements: ["CommonJS/Modules/1.0"]
  directories:
    lib: "."

coffeefiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.coffee$/.test f

jsfiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.js$/.test f

compile_webactors_js = ->
  files = coffeefiles("src")
  compiled = for src in files
    data = fs.readFileSync src, "utf8"
    try
      coffee.compile(data)
    catch e
      e.message = "#{src}: #{e.message}"
      throw e
  compiled.join("\n")

task "build", "Build delectable files.", ->
  src = compile_webactors_js()
  fs.mkdir "dist", 0755, (err) ->
    fs.writeFile "dist/webactors.js", src, ->
      fs.writeFile "dist/webactors.min.js", jsmin(src)

prohibit_bad_paths = (path, cb) ->
  if path.search(/\.\./) isnt -1 or path.substr(path.length - 1, 1) is "/"
    err = errnoException(EACCES, path)
  else
    err = errnoException(ENOENT, path)
  cb(err, null)

read_file_content = (path, cb) ->
  fs.readFile path, cb

serve_webactors_js = (path, cb) ->
  if path isnt "lib/webactors.js"
    err = errnoException(ENOENT, path)
    cb(err, null)
    return
  try
    src = compile_webactors_js()
    cb(null, new Buffer(src, "utf8"))
  catch e
    cb(e, null)

get_file_extension = (path) ->
  m = /\.([a-z]+)$/.exec(path)
  if m
    return m[1]
  else
    return ""

transcode_coffeescript = (path, cb) ->
  ext = get_file_extension(path)
  unless ext is "js"
    err = errnoException(ENOENT, path)
    cb(err, null)
    return
  coffee_path = path.replace(/\.js$/, '.coffee')
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

compose_two_content_sources = (a, b) ->
  (path, cb) ->
    a path, (err, data) ->
      if err and err.errno is ENOENT
        b path, cb
      else
        cb(err, data)

compose_content_sources = (composed, remaining...) ->
  for source in remaining
    composed = compose_two_content_sources(composed, source)
  composed

get_content = compose_content_sources prohibit_bad_paths,
                                      serve_webactors_js,
                                      read_file_content,
                                      transcode_coffeescript

CONTENT_TYPES =
  html: 'text/html'
  css: 'text/css'
  js: 'text/javascript'

task "spec", "Serve yummy specs.", ->
  server = http.createServer (request, response) ->
    if request.method isnt "HEAD" and request.method isnt "GET"
      headers =
        'Content-Type': 'text/plain'
        'Allow': 'GET, HEAD'
      response.writeHead(405, headers)
      response.write("405 Method Not Allowed\n")
      response.end()
      return
    path = url.parse(request.url).pathname
    ext = get_file_extension(path)
    path = path.substr(1) # remove leading /
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
