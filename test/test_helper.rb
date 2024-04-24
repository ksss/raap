# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

if ENV['COVERAGE']
  require "coverage"
  module MinimumCov
    def self.start
      Coverage.start
      at_exit do
        target = File.expand_path("../lib", __dir__)
        snip = "#{File.expand_path("..", __dir__)}/"
        cov = Coverage.result.select { |d| d.match?(target) }
        total = cov.values.flatten.compact
        total_cov = total.count { |l| l > 0 }
        total_missed = total.count { |l| l == 0 }
        total_percent = total_cov.fdiv(total.length)

        summary = cov.dup
        summary.transform_keys! { |key| key.sub(snip, '\1') }
        summary.transform_values! do |ary|
          ary = ary.compact
          ary.count { |l| l > 0 }.fdiv(ary.length)
        end
        max_length = summary.keys.max_by(&:length).length

        puts
        puts "# Minimum Coverage"
        puts
        puts "All Files ( %4.2f %% covered at %.1f hits/line )" % [total_percent * 100, total.sum.fdiv(total.length)]
        puts "%d files in total." % cov.length
        puts "%d relevant lines, %d lines covered and %d lines missed. ( %.2f %% )" % [total.length, total_cov, total_missed, total_percent * 100]
        puts
        puts "| %-#{max_length}s |  covered |" % ["File"]
        puts "|:%-#{max_length}s-|---------:|" % ["-" * max_length]
        summary.sort_by { |k, v| v }.each do |k, v|
          puts "| %-#{max_length}s | %6.2f %% |" % [k, v * 100]
        end
      end
    end
  end
  MinimumCov.start
end

require "minitest/autorun"
require "raap"
require "raap/minitest"

require_relative './test'

RaaP::RBS.loader.add(path: Pathname('test/test.rbs'))
