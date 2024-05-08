# frozen_string_literal: true

require "test_helper"

class TestCoverage < Minitest::Test
  Coverage = RaaP::Coverage

  def g(str) = "\e[32m#{str}\e[0m"
  def r(str) = "\e[1;4;41m#{str}\e[0m"
  def y(str) = "\e[93m#{str}\e[0m"

  def test_log
    Coverage.log("before")
    Coverage.start(::RBS::Parser.parse_method_type("(String) -> String"))
    assert Set.new == Coverage.cov
    Coverage.log("after")
    assert Set.new([:after]) == Coverage.cov
  end

  def test_show_req
    Coverage.start(::RBS::Parser.parse_method_type("(String) -> String"))

    Coverage.show(io = StringIO.new)
    assert_equal "(#{r("String")}) -> #{r("String")}\n", io.string

    Coverage.log(:req_0)
    Coverage.show(io = StringIO.new)
    assert_equal "(#{g("String")}) -> #{r("String")}\n", io.string

    Coverage.log(:return)
    Coverage.show(io = StringIO.new)
    assert_equal "(#{g("String")}) -> #{g("String")}\n", io.string
  end

  def test_show_req_union
    Coverage.start(::RBS::Parser.parse_method_type("(String | Integer) -> String"))

    Coverage.show(io = StringIO.new)
    assert_equal "(#{r("String")} | #{r("Integer")}) -> #{r("String")}\n", io.string

    Coverage.log(:req_0_union_0)
    Coverage.show(io = StringIO.new)
    assert_equal "(#{g("String")} | #{r("Integer")}) -> #{r("String")}\n", io.string

    Coverage.log(:req_0_union_1)
    Coverage.show(io = StringIO.new)
    assert_equal "(#{g("String")} | #{g("Integer")}) -> #{r("String")}\n", io.string
  end

  def test_show_opt
    Coverage.start(::RBS::Parser.parse_method_type("(?String, ?Integer) -> void"))

    Coverage.show(io = StringIO.new)
    assert_equal "(?#{r "String"}, ?#{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:opt_0)
    Coverage.show(io = StringIO.new)
    assert_equal "(?#{g "String"}, ?#{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:opt_1)
    Coverage.show(io = StringIO.new)
    assert_equal "(?#{g "String"}, ?#{g "Integer"}) -> #{r "void"}\n", io.string
  end

  def test_show_rest
    Coverage.start(::RBS::Parser.parse_method_type("(*String) -> void"))

    Coverage.show(io = StringIO.new)
    assert_equal "(*#{r "String"}) -> #{r "void"}\n", io.string

    Coverage.log(:rest)
    Coverage.show(io = StringIO.new)
    assert_equal "(*#{g "String"}) -> #{r "void"}\n", io.string
  end

  def test_show_keyreq
    Coverage.start(::RBS::Parser.parse_method_type("(a: String, b: Integer) -> void"))

    Coverage.show(io = StringIO.new)
    assert_equal "(a: #{r "String"}, b: #{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:keyreq_a)
    Coverage.show(io = StringIO.new)
    assert_equal "(a: #{g "String"}, b: #{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:keyreq_b)
    Coverage.show(io = StringIO.new)
    assert_equal "(a: #{g "String"}, b: #{g "Integer"}) -> #{r "void"}\n", io.string
  end

  def test_show_key
    Coverage.start(::RBS::Parser.parse_method_type("(?a: String, ?b: Integer) -> void"))

    Coverage.show(io = StringIO.new)
    assert_equal "(?a: #{r "String"}, ?b: #{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:key_a)
    Coverage.show(io = StringIO.new)
    assert_equal "(?a: #{g "String"}, ?b: #{r "Integer"}) -> #{r "void"}\n", io.string

    Coverage.log(:key_b)
    Coverage.show(io = StringIO.new)
    assert_equal "(?a: #{g "String"}, ?b: #{g "Integer"}) -> #{r "void"}\n", io.string
  end

  def test_show_keyrest
    Coverage.start(::RBS::Parser.parse_method_type("(**String) -> void"))

    Coverage.show(io = StringIO.new)
    assert_equal "(**#{r "String"}) -> #{r "void"}\n", io.string

    Coverage.log(:keyrest)
    Coverage.show(io = StringIO.new)
    assert_equal "(**#{g "String"}) -> #{r "void"}\n", io.string
  end

  def test_show_block
    Coverage.start(::RBS::Parser.parse_method_type("() { (Integer, String) -> void } -> String"))

    Coverage.show(io = StringIO.new)
    assert_equal "() { (#{r("Integer")}, #{r("String")}) -> #{r("void")} } -> #{r("String")}\n", io.string

    Coverage.log(:block_param_0)
    Coverage.show(io = StringIO.new)
    assert_equal "() { (#{g("Integer")}, #{r("String")}) -> #{r("void")} } -> #{r("String")}\n", io.string

    Coverage.log(:block_return)
    Coverage.show(io = StringIO.new)
    assert_equal "() { (#{g("Integer")}, #{r("String")}) -> #{g("void")} } -> #{r("String")}\n", io.string

    Coverage.log(:block_param_1)
    Coverage.show(io = StringIO.new)
    assert_equal "() { (#{g("Integer")}, #{g("String")}) -> #{g("void")} } -> #{r("String")}\n", io.string
  end

  def attr_(kind, return_type)
    content = "attr_#{kind} a: #{return_type}\n"
    ::RBS::MethodType.new(
      type_params: [],
      type: ::RBS::Types::Function.empty(::RBS::Parser.parse_type(return_type)),
      block: nil,
      location: ::RBS::Location.new(
        buffer: ::RBS::Buffer.new(
          name: "test_coverage.rbs",
          content: content
        ),
        start_pos: 0,
        end_pos: content.length,
      ).tap { |l| l.add_required_child(:keyword, 0...kind.length) },
    )
  end

  def test_show_attr_reader_class_instance
    Coverage.start(attr_(:reader, "String"))

    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{r("String")}\n", io.string

    Coverage.log(:return)
    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{g("String")}\n", io.string
  end

  def test_show_attr_reader_union
    Coverage.start(attr_(:reader, ":foo | :bar"))

    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{r(":foo")} | #{r(":bar")}\n", io.string

    Coverage.log(:return_union_0)
    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{g(":foo")} | #{r(":bar")}\n", io.string

    Coverage.log(:return_union_1)
    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{g(":foo")} | #{g(":bar")}\n", io.string
  end

  def test_show_attr_reader_optional
    Coverage.start(attr_(:reader, "String?"))

    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{r "String"}#{r ??}\n", io.string

    Coverage.log(:return_optional_left)
    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{g "String"}#{r ??}\n", io.string

    Coverage.log(:return_optional_right)
    Coverage.show(io = StringIO.new)
    assert_equal "attr_reader a: #{g "String"}#{g ??}\n", io.string
  end

  def test_show_return_union
    Coverage.start(::RBS::Parser.parse_method_type("() -> (String | Integer)"))

    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"} | #{r "Integer"})\n", io.string

    Coverage.log(:return_union_0)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{g "String"} | #{r "Integer"})\n", io.string

    Coverage.log(:return_union_1)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{g "String"} | #{g "Integer"})\n", io.string
  end

  def test_show_return_optional
    Coverage.start(::RBS::Parser.parse_method_type("() -> String?"))

    Coverage.show(io = StringIO.new)
    assert_equal "() -> #{r "String"}#{r ??}\n", io.string

    Coverage.log(:return_optional_left)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> #{g "String"}#{r ??}\n", io.string

    Coverage.log(:return_optional_right)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> #{g "String"}#{g ??}\n", io.string
  end

  def test_show_return_union_with_optional
    Coverage.start(::RBS::Parser.parse_method_type("() -> (String? | Integer?)"))

    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"}#{r ??} | #{r "Integer"}#{r ??})\n", io.string

    Coverage.log(:return_union_1_optional_right)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"}#{r ??} | #{r "Integer"}#{g ??})\n", io.string

    Coverage.log(:return_union_1_optional_left)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"}#{r ??} | #{g "Integer"}#{g ??})\n", io.string

    Coverage.log(:return_union_0_optional_left)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{g "String"}#{r ??} | #{g "Integer"}#{g ??})\n", io.string

    Coverage.log(:return_union_0_optional_right)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{g "String"}#{g ??} | #{g "Integer"}#{g ??})\n", io.string
  end

  def test_show_return_optional_with_union
    Coverage.start(::RBS::Parser.parse_method_type("() -> (String | Integer)?"))

    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"} | #{r "Integer"})#{r ??}\n", io.string

    Coverage.log(:return_optional_right)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"} | #{r "Integer"})#{g ??}\n", io.string

    Coverage.log(:return_optional_left_union_1)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{r "String"} | #{g "Integer"})#{g ??}\n", io.string

    Coverage.log(:return_optional_left_union_0)
    Coverage.show(io = StringIO.new)
    assert_equal "() -> (#{g "String"} | #{g "Integer"})#{g ??}\n", io.string
  end
end
