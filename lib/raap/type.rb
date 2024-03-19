# frozen_string_literal: true

module RaaP
  # Type.new("Integer").pick(size: 10) #=> 2
  # Type.new("Symbol").pick(size: 6) #=> :abcdef
  # Type.new("Array[Integer]").pick(size: 3) #=> [1, 2, 3]
  # Type.new("Array[Integer]") { sized { |size| Array.new(size + 1) { integer.pick(size: size) } } }
  class Type
    module Arithmetic
      def self.float
        positive_float.then { |x| [x, -x].sample or raise }
      end

      def self.positive_float
        x = Random.rand
        x / Math.sqrt(1 - x * x)
      end
    end

    GENERATORS = {}
    SIMPLE_SOURCE = ('a'..'z').to_a << '_'
    RECURSION = Hash.new { |h, k| h[k] = { count: 0, logged: false } }

    # Type.register "::Integer::positive" { sized { |size| size } }
    def self.register(type_name, &block)
      GENERATORS[type_name] = block
    end

    def self.list
      RBS.env.class_decls.keys.map(&:to_s)
    end

    # Special class case
    register("::Array") do
      t = type.args[0] || 'untyped'
      array(Type.new(t, range: range))
    end
    register("::Binding") { sized { binding } }
    register("::Complex") { complex }
    register("::Data") { sized { Data.define } }
    register("::Encoding") { encoding }
    register("::FalseClass") { sized { false } }
    register("::Float") { float }
    register("::Hash") do
      sized do |size|
        Array.new(integer.pick(size: size).abs).to_h do
          k = type.args[0] || 'untyped'
          v = type.args[1] || 'untyped'
          [Type.new(k).pick(size: size), Type.new(v).pick(size: size)]
        end
      end
    end
    register("::Integer") { integer }
    register("::IO") { sized { StringIO.new } } # FIXME StringIO is not IO
    register("::Method") { sized { temp_method_object } }
    register("::NilClass") { sized { nil } }
    register("::Proc") { sized { Proc.new {} } }
    register("::Rational") { rational }
    register("::Regexp") { sized { |size| Regexp.new(string.pick(size: size)) } }
    register("::String") { string }
    register("::Struct") { sized { Struct.new(:foo, :bar).new } }
    register("::Symbol") { symbol }
    register("::Time") { sized { Time.now } }
    register("::TrueClass") { sized { true } }
    register("::UnboundMethod") { sized { temp_method_object.unbind } }

    attr_reader :type
    attr_reader :range

    def initialize(type, range: nil..nil, &block)
      @type = parse(type)
      @range = range
      @block = block
    end

    def sized(&block)
      Sized.new(&block)
    end

    def pick(size: 10, eval: true)
      symb = to_symbolic_call(size:)
      eval ? SymbolicCaller.new(symb).eval : symb
    end

    def to_symbolic_call(size:)
      raise ArgumentError, "negative size" if size.negative?
      return instance_exec(&@block).pick(size: size) if @block

      case type
      when ::RBS::Types::Tuple
        type.types.map { |t| Type.new(t).pick(size:) }
      when ::RBS::Types::Union
        type.types.sample&.then { |t| Type.new(t).pick(size:) }
      when ::RBS::Types::Intersection
        Value::Intersection.new(type, size: size)
      when ::RBS::Types::Optional
        case Random.rand(2)
        in 0 then Type.new(type.type).pick(size:)
        in 1 then nil
        end
      when ::RBS::Types::Alias
        case gen = GENERATORS[type.name.absolute!.to_s]
        in Proc then instance_exec(&gen)
        in nil then Type.new(RBS.builder.expand_alias2(type.name, type.args)).pick(size:)
        end
      when ::RBS::Types::Bases::Class
        raise "cannot resolve `class` type"
      when ::RBS::Types::Bases::Instance
        raise "cannot resolve `instance` type"
      when ::RBS::Types::Bases::Self
        raise "cannot resolve `self` type"
      when ::RBS::Types::Interface
        Value::Interface.new(type, size: size)
      when ::RBS::Types::Variable
        Value::Variable.new(type)
      when ::RBS::Types::ClassSingleton
        Object.const_get(type.name.to_s)
      when ::RBS::Types::ClassInstance
        case gen = GENERATORS[type.name.absolute!.to_s]
        when Proc then instance_exec(&gen).pick(size: size)
        when nil then pick_from_initialize(type, size:)
        end
      when ::RBS::Types::Record
        type.fields.transform_values { |t| Type.new(t).pick(size:) }
      when ::RBS::Types::Proc
        Proc.new { Type.new(type.type.return_type).pick(size:) }
      when ::RBS::Types::Literal
        type.literal
      when ::RBS::Types::Bases::Bool
        bool.pick(size: size)
      when ::RBS::Types::Bases::Void
        Value::Void.new
      when ::RBS::Types::Bases::Any
        untyped.pick(size: size)
      when ::RBS::Types::Bases::Nil
        nil
      when ::RBS::Types::Bases::Top
        Value::Top.new
      when ::RBS::Types::Bases::Bottom
        Value::Bottom.new
      else
        raise "not implemented #{type.to_s}"
      end
    end

    def pick_from_initialize(type, size:)
      type_name = type.name.absolute!
      const = Object.const_get(type_name.to_s)
      definition = RBS.builder.build_singleton(type_name)
      snew = definition.methods[:new]
      if snew
        # class
        rbs_method_type = snew.method_types.sample or raise
        type_params = definition.type_params_decl.concat(rbs_method_type.type_params.drop(definition.type_params_decl.length))
        ts = TypeSubstitution.new(type_params, type.args)
        maped_rbs_method_type = rbs_method_type
        maped_rbs_method_type = ts.method_type_sub(rbs_method_type)
        method_type = MethodType.new(maped_rbs_method_type)

        begin
          try(times: 5, size: size) do |size|
            args, kwargs, block = method_type.pick_arguments(size: size, eval: false)
            [:call, const, :new, args, kwargs, block]
          end
        rescue
          $stderr.puts "Fail with `#{rbs_method_type}`"
          raise
        end
      else
        Value::Module.new(type)
      end
    end

    private

    def parse(type)
      case type
      when String
        RBS.parse_type(type) or raise "cannot parse #{type.inspect}"
      when ::RBS::TypeName
        parse(type.to_s)
      else
        type
      end
    end

    def try(times:, size:)
      # @type var error: Exception?
      ret = error = nil
      times.times do
        ret = yield size
        if ret
          error = nil
          break
        end
      rescue => e
        size += 1
        error = e
        next
      end

      if error
        $stderr.puts
        $stderr.puts "=== Catch error when generating type `#{type}`. Please check your RBS or RaaP bug. ==="
        $stderr.puts "(#{error.class}) #{error.message}"
        raise error
      end

      ret
    end

    def integer
      sized { |size| float.pick(size: size).round }
    end

    def none_zero_integer
      integer.such_that { |i| i != 0 }
    end

    def float
      sized do |size|
        case [@range.begin, @range.end]
        in nil, nil
          Arithmetic.float * size
        in nil, high
          high - Arithmetic.positive_float * size
        in low, nil
          low + Arithmetic.positive_float * size
        in low, high
          Random.rand(Range.new(low.to_f, high.to_f, @range.exclude_end?))
        end.round(2)
      end
    end

    def rational
      sized do |size|
        a = integer.pick(size: size)
        b = none_zero_integer.pick(size: size)
        [:call, Kernel, :Rational, [a, b], {}, nil]
      end
    end

    def complex
      sized do |size|
        a = integer.pick(size: size)
        b = none_zero_integer.pick(size: size)
        [:call, Kernel, :Complex, [a, b], {}, nil]
      end
    end

    def string
      sized do |size|
        if size == 0
          +""
        else
          case [@range.begin, @range.end]
          in nil, nil
            size.times.map { SIMPLE_SOURCE.sample }.join
          in nil, _
            raise "Should set range.begin and range.end"
          in _, nil
            raise "Should set range.begin and range.end"
          in s, e
            a = (s..e).to_a
            size.times.map { a.sample }.join
          end
        end
      end
    end

    def symbol
      sized do |size|
        string.pick(size: size).to_sym
      end
    end

    def array(type)
      sized do |size|
        Array.new(integer.pick(size: size).abs) do
          type.pick(size: size)
        end
      end
    end

    def encoding
      sized do
        e = Encoding.list.sample
        [Encoding, :find, [e.name], {} , nil]
      end
    end

    def bool
      sized { [true, false].sample }
    end

    def untyped
      case Random.rand(4)
      in 0 then integer
      in 1 then float
      in 2 then string
      in 3 then symbol
      in 4 then bool
      end
    end

    def temp_method_object
      o = Object.new
      m = 6.times.map { SIMPLE_SOURCE.sample }.join
      o.define_singleton_method(m) { }
      o.method(m)
    end
  end
end
