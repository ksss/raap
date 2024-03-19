# frozen_string_literal: true

module RaaP
  class Sized
    def initialize(&block)
      raise LocalJumpError, "no block given" unless block
      @block = block
      @such_that = nil
    end

    def pick(size:)
      such_that_loop do |skip|
        @block.call(size + skip)
      end
    end

    def such_that(&block)
      @such_that = block
      self
    end
    alias when such_that

    private

    def such_that_loop
      skip = 0
      while skip < 100
        picked = yield(skip)
        such_that = @such_that
        return picked if such_that.nil? || such_that.call(picked)
        skip += 1
        raise "too many skips" unless skip < 100
      end
      raise "never reached"
    end
  end
end
