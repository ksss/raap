# frozen_string_literal: true

require "test_helper"

class TestTypeSubstitution < Minitest::Test
  TypeSubstitution = RaaP::TypeSubstitution

  def test_method_type_sub
    ts = TypeSubstitution.new(
      [
        ::RBS::AST::TypeParam.new(name: :A, variance: :invariant, upper_bound: nil, location: nil)
      ],
      [
        RaaP::RBS.parse_type("Integer")
      ]
    )
    subed = ts.method_type_sub(RaaP::RBS.parse_method_type("[A] (A) -> A"))
    assert_equal "(Integer) -> Integer", subed.to_s
  end

  def test_method_type_sub_with_generic
    ts = TypeSubstitution.new(
      [
        ::RBS::AST::TypeParam.new(name: :A, variance: :invariant, upper_bound: nil, location: nil)
      ],
      [
        RaaP::RBS.parse_type("Integer")
      ]
    )
    subed = ts.method_type_sub(RaaP::RBS.parse_method_type("[A] (Object & _Each[A]) -> A"))
    assert_equal "(Object & _Each[Integer]) -> Integer", subed.to_s
  end

  def test_method_type_sub_with_upper_bound
    ts = TypeSubstitution.new(
      [
        ::RBS::AST::TypeParam.new(name: :A, variance: :invariant, upper_bound: RaaP::RBS.parse_type("Numeric"), location: nil)
      ],
      []
    )
    subed = ts.method_type_sub(RaaP::RBS.parse_method_type("[A] (A) -> A"))
    assert_equal "(Numeric) -> Numeric", subed.to_s
  end
end
