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

  def tests_eval_accessibility
    sc = [:call,
           [:call, Test::Accecibility, :new, [], {}, nil],
           :public_method, [], {}, nil]
    assert_nil SymbolicCaller.new(sc).eval

    sc = [:call,
           [:call, Test::Accecibility, :new, [], {}, nil],
           :private_method, [], {}, nil]
    assert_raises(NoMethodError) { SymbolicCaller.new(sc).eval }
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

  def test_to_lines_with_kernel
    sc = SymbolicCaller.new([
      :call, 3, :pow, [
        [:call, Kernel, :Rational, [-3, -11], {}, nil]
      ], {}, nil
    ])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      rational = Rational(-3, -11)
      3.pow(rational)
    CODE
  end

  def test_to_lines_end_with_singlaton_method
    sc = SymbolicCaller.new(
      [:call, Test::A, :singleton_method, [
        [:call, Test::B, :new, [], {}, nil]
      ], {}, nil])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      test_b = Test::B.new()
      Test::A.singleton_method(test_b)
    CODE
  end

  def test_to_lines_with_array
    sc = SymbolicCaller.new([:call, [1, 2, 3], :sum, [], {}, nil])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      [1, 2, 3].sum()
    CODE

    sc = SymbolicCaller.new([
      :call,
      [:call, Test::C, :new, [], {
        a: nil,
        b: [
          [:call, Test::A, :new, [[1, [2, [3]]]], {}, nil],
          [[[[:call, Test::B, :new, [], {}, nil]]]]
        ],
      }, nil],
      :run, [], {}, nil
    ])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      test_a = Test::A.new([1, [2, [3]]])
      test_b = Test::B.new()
      test_c = Test::C.new(a: nil, b: [test_a, [[[test_b]]]])
      test_c.run()
    CODE
  end

  def test_to_lines_with_hash
    sc = SymbolicCaller.new([:call, {a: {b: {c: 123}}}, :keys, [], {}, nil])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      {a: {b: {c: 123}}}.keys()
    CODE

    sc = SymbolicCaller.new([
      :call,
      [:call, Test::C, :new, [], {
        a: nil,
        b: {
          c: [:call, Test::A, :new, [{a: {b: {c: 123}}}], {}, nil],
          d: { e: [ { f: [:call, Test::B, :new, [], {b: {'b' => 1}}, nil] } ] }
        },
      }, nil],
      :run, [], {}, nil
    ])
    assert_equal <<~CODE.chomp, sc.to_lines.join("\n")
      test_a = Test::A.new({a: {b: {c: 123}}})
      test_b = Test::B.new(b: {'b' => 1})
      test_c = Test::C.new(a: nil, b: {c: test_a, d: {e: [{f: test_b}]}})
      test_c.run()
    CODE
  end
end
