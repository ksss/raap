# frozen_string_literal: true

require 'rbs'
require 'rbs/cli'
require 'rbs/test'
require 'optparse'
require 'timeout'
require 'logger'

require_relative 'raap/version'
require_relative 'raap/value'
require_relative 'shims'

module RaaP
  class << self
    attr_accessor :logger
  end

  self.logger = ::Logger.new($stdout, formatter: proc { |severity, _datetime, _progname, msg|
    "[RaaP] #{severity}: #{msg}\n"
  })
  self.logger.level = ::Logger::INFO

  autoload :BindCall, "raap/bind_call"
  autoload :CLI, "raap/cli"
  autoload :Coverage, "raap/coverage"
  autoload :FunctionType, "raap/function_type"
  autoload :MethodProperty, "raap/method_property"
  autoload :MethodType, "raap/method_type"
  autoload :RBS, "raap/rbs"
  autoload :Result, "raap/result"
  autoload :Sized, "raap/sized"
  autoload :SymbolicCaller, "raap/symbolic_caller"
  autoload :Type, "raap/type"
  autoload :TypeSubstitution, "raap/type_substitution"
  autoload :VERSION, "raap/version"
end
