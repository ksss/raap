# frozen_string_literal: true

require 'rbs'
require 'rbs/cli'
require 'rbs/test'
require 'optparse'
require 'timeout'
require 'logger'

require_relative 'raap/version'
require_relative 'raap/value'

module RaaP
  class << self
    attr_accessor :logger
  end

  self.logger = ::Logger.new($stdout)
  self.logger.level = ::Logger::WARN

  autoload :BindCall, "raap/bind_call"
  autoload :CLI, "raap/cli"
  autoload :FunctionType, "raap/function_type"
  autoload :MethodProperty, "raap/method_property"
  autoload :MethodType, "raap/method_type"
  autoload :MethodValue, "raap/method_value"
  autoload :RBS, "raap/rbs"
  autoload :Result, "raap/result"
  autoload :Sized, "raap/sized"
  autoload :SymbolicCaller, "raap/symbolic_caller"
  autoload :Type, "raap/type"
  autoload :TypeSubstitution, "raap/type_substitution"
  autoload :VERSION, "raap/version"
end
