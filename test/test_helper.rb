# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"

require "raap"
require "raap/minitest"

require_relative './test'

RaaP::RBS.loader.add(path: Pathname('test/test.rbs'))
