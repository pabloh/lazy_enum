# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "lazy_enum/version"

Gem::Specification.new do |s|
  s.name        = "lazy_enum"
  s.version     = LazyEnum::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Pablo Herrero"]
  s.email       = ["pablodherrero@gmail.com"]
  s.homepage    = "https://github.com/pabloh/lazy_enum"
  s.summary     = %q{Lazy Enumerable for Ruby}
  s.description = %q{Convert any Enumerable to lazy}

  s.rubyforge_project = "lazy_enum"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
