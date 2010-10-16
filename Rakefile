require 'rake/clean'

COFFEE_SCRIPTS = FileList['src/*.coffee', 'spec/*.coffee']
JAVA_SCRIPTS = COFFEE_SCRIPTS.map { |s| s.sub(/\.coffee$/, '.js') }
CLOBBER << JAVA_SCRIPTS

rule '.js' => '.coffee' do |t|
  sh "coffee", "-c", t.source
end

desc "Build files"
task :build => JAVA_SCRIPTS

task :default => :build
