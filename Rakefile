require 'rake/clean'

DIST_DIR = "dist"
RELEASE_FILE = File.join(DIST_DIR, "webactors.js")

COFFEE_SCRIPTS = FileList['src/*.coffee', 'spec/*.coffee']
JAVASCRIPTS = COFFEE_SCRIPTS.map { |s| s.sub(/\.coffee$/, '.js') }
CLOBBER << JAVASCRIPTS

rule '.js' => '.coffee' do |t|
  sh "coffee", "-c", t.source
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
