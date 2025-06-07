# frozen_string_literal: true

require_relative "lib/raap/version"

Gem::Specification.new do |spec|
  spec.name = "raap"
  spec.version = RaaP::VERSION
  spec.authors = ["ksss"]
  spec.email = ["co000ri@gmail.com"]

  spec.summary = "RBS as a Property"
  spec.description = "Property based testing tool with RBS"
  spec.homepage = "https://github.com/ksss/raap"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      f.start_with?(*%w[lib/ exe/ CHANGELOG.md CODE_OF_CONDUCT.md LICENSE.txt README.md])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rbs", "~> 3.9.0"
  spec.add_dependency "timeout", "~> 0.4"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
