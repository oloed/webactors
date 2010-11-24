begin
  require 'rubygems'
rescue LoadError
end
require 'rake/clean'
require 'coffee_script'

DIST_DIR = "dist"
COMBINED_JAVASCRIPT = File.join(DIST_DIR, "webactors.js")
COMBINED_MINIFIED_JAVASCRIPT = COMBINED_JAVASCRIPT.sub(/\.js$/, '.min.js')
RELEASE_FILES = [COMBINED_JAVASCRIPT, COMBINED_MINIFIED_JAVASCRIPT]

JAVASCRIPTS = FileList['src/*.coffee'].map { |s| s.sub(/\.coffee$/, '.js') }
JAVASCRIPT_SPECS = FileList['spec/*.coffee'].map { |s| s.sub(/\.coffee$/, '.js') }

CLEAN << JAVASCRIPTS
CLOBBER << RELEASE_FILES
CLOBBER << JAVASCRIPT_SPECS

rule '.js' => '.coffee' do |t|
  puts "building #{t.name}"
  File.open t.name, "w" do |output|
    File.open t.source, "r" do |input|
      output.write CoffeeScript.compile(input.read)
    end
  end
end

directory DIST_DIR

file COMBINED_JAVASCRIPT => [DIST_DIR] + JAVASCRIPTS do
  open COMBINED_JAVASCRIPT, "w" do |output|
    for script in JAVASCRIPTS
      open script, "r" do |input|
        output.write input.read
      end
    end
  end
end

file COMBINED_MINIFIED_JAVASCRIPT => COMBINED_JAVASCRIPT do
  puts "minifying #{COMBINED_JAVASCRIPT}"
  system "yui-compressor", "-o", COMBINED_MINIFIED_JAVASCRIPT, COMBINED_JAVASCRIPT
end

desc "Build files"
task :build => RELEASE_FILES + JAVASCRIPT_SPECS

task :default => :build
