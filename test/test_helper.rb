# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"

require "raap"

require_relative './test'

RaaP::RBS.loader.add(path: Pathname('test/test.rbs'))

def forall(*types)
  (0...10).each do |size|
    vals = types.map do |type|
      case type
      in String then RaaP::Type.new(type)
      in RaaP::Type then type
      end.pick(size: size)
    end
    assert yield(*vals)
  end
end
