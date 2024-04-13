# frozen_string_literal: true

require "test_helper"

class TestMethodProperty < Minitest::Test
  MethodProperty = RaaP::MethodProperty
  MethodType = RaaP::MethodType
  Type = RaaP::Type
  Result = RaaP::Result

  def test_run
    count = 0
    stats = MethodProperty.new(
      receiver_type: Type.new("Test::Property"),
      method_name: :method_property1,
      method_type: MethodType.new("() -> true"),
      size_step: 0...100,
      timeout: 2,
    ).run do |called|
      count += 1
      case called
      in Result::Success
      in Result::Failure
      in Result::Skip
      in Result::Exception
      end
    end

    assert_equal 100, count
    assert_kind_of(MethodProperty::Stats, stats)
  end

  def test_run_with_break
    count = 0
    stats = MethodProperty.new(
      receiver_type: Type.new("Test::Property"),
      method_name: :method_property1,
      method_type: MethodType.new("() -> true"),
      size_step: 0...100,
      timeout: 2,
    ).run do |_called|
      count += 1
      throw :break
    end

    assert_equal 1, count
    assert_kind_of(MethodProperty::Stats, stats)
  end

  def test_run_with_timeout
    original = RaaP.logger.level
    RaaP.logger.level = Logger::ERROR
    count = 0
    prop = MethodProperty.new(
      receiver_type: Type.new("Test::Sleep"),
      method_name: :sleep,
      method_type: MethodType.new("() -> bot"),
      size_step: 0...100,
      timeout: 0.01,
    )
    stats = prop.run { count += 1 }

    assert_equal 0, count
    assert_equal 0, stats.exception
  ensure
    RaaP.logger.level = original
  end

  def test_polymorphic_without_type_argument
    prop = MethodProperty.new(
      receiver_type: Type.new("Test::List"),
      method_name: :add,
      method_type: MethodType.new("[T] (T) -> self"),
      size_step: 0...10,
      timeout: 3,
    )
    stats = prop.run do |called|
      case called
      when Result::Exception
        raise called.exception
      end
    end
    assert_equal 0, stats.exception
  end

  def test_return_type_has_error
    prop = MethodProperty.new(
      receiver_type: Type.new("Array[Integer]"),
      method_name: :max_by,
      method_type: MethodType.new("(-10) -> Enumerator[untyped,untyped]"),
      size_step: 0...10,
      timeout: 1,
    )
    stats = prop.run do |called|
      case called
      in Result::Exception
        # ok
      end
    end
    assert_equal 10, stats.exception
  end
end
