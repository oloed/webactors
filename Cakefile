cs  = require "coffee-script"
fs  = require "fs"
min = require "jsmin"
sys = require "sys"

coffeefiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.coffee$/.test f

jsfiles = (dir) ->
  "#{dir}/#{f}" for f in fs.readdirSync dir when /\.js$/.test f

task "build", "Build files.", ->
  files = coffeefiles("src").concat coffeefiles("spec")

  for src in files
    data = fs.readFileSync src, "utf8"
    fs.writeFileSync src.replace(/\.coffee$/, ".js"), cs.compile(data)

  fs.mkdir "dist", 0755, (err) ->
    src = (fs.readFileSync(f, "utf8") for f in jsfiles("src")).join "\n"

    fs.writeFile "dist/webactors.js", src, (err) ->
      throw err if err
