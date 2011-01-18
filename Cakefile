coffee = require "coffee-script"
fs     = require "fs"
jsmin  = require("jsmin").jsmin
sys    = require "sys"
http   = require "http"
url    = require "url"
spawn  = require("child_process").spawn
exec   = require("child_process").exec

binding = process.binding('net')

ENOENT = binding.ENOENT
EPERM = binding.EPERM
EACCES = binding.EACCES
getsockname = binding.getsockname
errnoException = binding.errnoException

PROJECT = "webactors"
VERSION = "0.0.0"
AUTHOR =
  name: "MenTaLguY"
  email: "mental@rydia.net"
  url: "http://moonbase.rydia.net"

NPM_PACKAGE_SPEC =
  name: PROJECT
  version: VERSION
  author: AUTHOR
  description: "WebActors is an implementation of the actor model for concurrent programming."
  keywords: ["concurrency", "actor"]
  main: "lib/webactors"
  directories:
    lib: "./lib"

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

mkdir_p = (path, callback) ->
  p = spawn('mkdir', ['-p', '--', path])
  p.on 'exit', ->
    callback()
 
task "build", "Build delectable files.", ->
  src = compile_webactors_js()
  versioned_package = "#{PROJECT}-#{VERSION}"

  standalone_dir = "dist/standalone"
  mkdir_p standalone_dir, ->
    fs.writeFileSync "#{standalone_dir}/#{versioned_package}.js", src
    fs.writeFileSync "#{standalone_dir}/#{versioned_package}.min.js", jsmin(src)

  npm_dir = "dist/npm"
  npm_package_dir = "#{npm_dir}/#{versioned_package}"
  npm_lib_dir = "#{npm_package_dir}/lib"
  mkdir_p npm_lib_dir, ->
    package_json = JSON.stringify(NPM_PACKAGE_SPEC)
    fs.writeFileSync "#{npm_package_dir}/package.json", package_json
    fs.writeFileSync "#{npm_lib_dir}/webactors.js", src
    exec("cd #{npm_dir} && tar zcvf #{versioned_package}.tar.gz #{versioned_package}")

task "clean", "Clean dirty leftovers.", ->
  spawn('rm', ['-rf', 'dist'])

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
