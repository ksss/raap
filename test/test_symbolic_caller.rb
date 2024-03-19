# frozen_string_literal: true

require "test_helper"

class TestSymbolicCaller < Minitest::Test
  SymbolicCaller = RaaP::SymbolicCaller

  def test_eval_simple
    sc = SymbolicCaller.new([:call, Test::A, :new, [], {}, nil])
    assert_instance_of Test::A, sc.eval
  end

  def test_eval_nested
    sc = SymbolicCaller.new([
      :call,
      [:call, Test::C, :new, [], {
        a: [:call, Test::A, :new, [], {}, nil],
        b: [:call, Test::B, :new, [], {}, nil],
      }, nil],
      :run, [], {}, nil
    ])
    assert_instance_of Integer, sc.eval
  end

  def test_to_lines
    sc = SymbolicCaller.new([
      :call,
      [:call, Test::C, :new, [], {
        a: [:call, Test::A, :new, [], {}, nil],
        b: [:call, Test::B, :new, [], {}, nil],
      }, nil],
      :run, [], {}, nil
    ])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      test_a = Test::A.new()
      test_b = Test::B.new()
      test_c = Test::C.new(a: test_a, b: test_b)
      test_c.run()
    CODE
  end
end
