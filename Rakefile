begin
  require 'rubygems'
rescue LoadError
end
require 'rake/clean'
require 'coffee_script'

DIST_DIR = "dist"
RELEASE_FILE = File.join(DIST_DIR, "webactors.js")

JAVASCRIPTS = FileList['src/*.coffee'].map { |s| s.sub(/\.coffee$/, '.js') }
JAVASCRIPT_SPECS = FileList['spec/*.coffee'].map { |s| s.sub(/\.coffee$/, '.js') }

CLEAN << JAVASCRIPTS
CLEAN << JAVASCRIPT_SPECS
CLOBBER << RELEASE_FILE

rule '.js' => '.coffee' do |t|
  File.open t.name, "w" do |output|
    File.open t.source, "r" do |input|
      output.write CoffeeScript.compile(input.read)
    end
  end
end

desc "Build files"
task :build => RELEASE_FILE

directory DIST_DIR

file RELEASE_FILE => [DIST_DIR] + JAVASCRIPTS do
  open RELEASE_FILE, "w" do |output|
    for script in JAVASCRIPTS
      open script, "r" do |input|
        output.write input.read
      end
    end
  end
end

task :default => :build
