require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "nu_wav"
    gem.summary = %Q{NuWav is a pure ruby audio WAV file parser and writer.}
    gem.description = %Q{NuWav is a pure ruby audio WAV file parser and writer.  It supports Broadcast Wave Format (BWF), inclluding MPEG audio data, and the public radio standard cart chunk.}
    gem.email = "andrew@beginsinwonder.com"
    gem.homepage = "http://github.com/kookster/nu_wav"
    gem.authors = ["kookster"]
    gem.add_dependency('ruby-mp3info', '>= 0.6.13')
    gem.files.exclude ".document"
    gem.files.exclude ".gitignore"
    gem.files.exclude "test/files/**/*"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "nu_wav #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
