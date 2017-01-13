# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nu_wav/version'

Gem::Specification.new do |spec|
  spec.name          = "nu_wav"
  spec.version       = NuWav::VERSION
  spec.authors       = ["Andrew Kuklewicz"]
  spec.email         = ["andrew@beginsinwonder.com"]
  spec.description   = %q{NuWav is a pure ruby audio WAV file parser and writer.  It supports Broadcast Wave Format (BWF), inclluding MPEG audio data, and the public radio standard cart chunk.}
  spec.summary       = %q{NuWav is a pure ruby audio WAV file parser and writer.}
  spec.homepage      = %q{http://github.com/kookster/nu_wav}
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ruby-mp3info", ">= 0.6.13"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test-unit"
end
