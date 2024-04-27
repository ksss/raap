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
        x / Math.sqrt(1 - (x * x))
      end
    end

    GENERATORS = {}
    SIMPLE_SOURCE = ('a'..'z').to_a << '_'

    # Type.register "::Integer::positive" { sized { |size| size } }
    def self.register(type_name, &block)
      raise ArgumentError, "block is required" unless block

      type_name = "::#{type_name}" if !type_name.start_with?("::")
      GENERATORS[type_name] = __skip__ = block
    end

    def self.random
      Type.new("Integer | Float | Rational | Complex | String | Symbol | bool | Encoding | BasicObject | nil | Time")
    end

    def self.random_without_basic_object
      random.tap do |r|
        # @type var rtype: ::RBS::Types::Union
        rtype = r.type
        rtype.types.reject! { |t| t.to_s == "BasicObject" }
      end
    end

    def self.call_new_from(base, type, size:)
      type_name = type.name.absolute!
      definition = RBS.builder.build_singleton(type_name)
      snew = definition.methods[:new]
      if snew
        # class
        rbs_method_type = snew.method_types.sample or raise
        type_params = definition.type_params_decl.concat(rbs_method_type.type_params.drop(definition.type_params_decl.length))
        ts = TypeSubstitution.new(type_params, type.args)
        maped_rbs_method_type = ts.method_type_sub(rbs_method_type)
        method_type = MethodType.new(maped_rbs_method_type)

        begin
          args, kwargs, block = method_type.arguments_to_symbolic_call(size: size)
          [:call, base, :new, args, kwargs, block]
        rescue
          $stderr.puts "Fail with `#{rbs_method_type}`"
          raise
        end
      else
        [:call, Value::Module, :new, [type.to_s], { size: size }, nil]
      end
    end

    # Special class case
    register("::Array") do
      instance = __skip__ = type
      t = instance.args[0] ? Type.new(instance.args[0], range: range) : Type.random
      array(t)
    end
    register("::Binding") { binding }
    register("::Complex") { complex }
    register("::Data") { Data.define }
    register("::Encoding") { encoding }
    register("::FalseClass") { false }
    register("::Float") { float }
    register("::Hash") do
      instance = __skip__ = type
      key = instance.args[0] ? Type.new(instance.args[0]) : Type.random_without_basic_object
      value = instance.args[1] ? Type.new(instance.args[1]) : Type.random
      dict(key, value)
    end
    register("::Integer") { integer }
    register("::IO") { $stdout }
    register("::Method") { temp_method_object }
    register("::NilClass") { nil }
    register("::Proc") { Proc.new {} }
    register("::Rational") { rational }
    register("::Regexp") { sized { |size| Regexp.new(string.pick(size: size)) } }
    register("::String") { string }
    register("::Struct") { Struct.new(:foo, :bar).new }
    register("::Symbol") { symbol }
    register("::Time") { [:call, Time, :now, [], {}, nil] }
    register("::TrueClass") { true }
    register("::UnboundMethod") { temp_method_object.unbind }

    attr_reader :type
    attr_reader :range

    def initialize(type, range: nil..nil)
      @type = parse(type)
      @range = range
      @such_that = nil
    end

    def such_that(&block)
      @such_that = block
      self
    end

    def sized(&block)
      Sized.new(&block).tap do |sized|
        if (s = @such_that)
          sized.such_that(&s)
        end
      end
    end

    def pick(size: 10)
      to_symbolic_caller(size: size).eval
    end

    def to_symbolic_caller(size: 10)
      SymbolicCaller.new(to_symbolic_call(size: size))
    end

    def to_symbolic_call(size: 10)
      raise TypeError, "size should be Integer" unless size.is_a?(Integer)
      raise ArgumentError, "negative size" if size.negative?

      case type
      when ::RBS::Types::Tuple
        type.types.map { |t| Type.new(t).to_symbolic_call(size: size) }
      when ::RBS::Types::Union
        type.types.sample&.then { |t| Type.new(t).to_symbolic_call(size: size) }
      when ::RBS::Types::Intersection
        if type.free_variables.empty?
          [:call, Value::Intersection, :new, [type.to_s], { size: size }, nil]
        else
          [:call, Value::Intersection, :new, [type], { size: size }, nil]
        end
      when ::RBS::Types::Interface
        if type.free_variables.empty?
          [:call, Value::Interface, :new, [type.to_s], { size: size }, nil]
        else
          [:call, Value::Interface, :new, [type], { size: size }, nil]
        end
      when ::RBS::Types::Variable
        [:call, Value::Variable, :new, [type.to_s], {}, nil]
      when ::RBS::Types::Bases::Void
        [:call, Value::Void, :new, [], {}, nil]
      when ::RBS::Types::Bases::Top
        [:call, Value::Top, :new, [], {}, nil]
      when ::RBS::Types::Bases::Bottom
        [:call, Value::Bottom, :new, [], {}, nil]
      when ::RBS::Types::Optional
        case Random.rand(2)
        in 0 then Type.new(type.type).to_symbolic_call(size: size / 2)
        in 1 then nil
        end
      when ::RBS::Types::Alias
        case gen = GENERATORS[type.name.absolute!.to_s]
        in Proc then instance_exec(&gen)
        in nil then Type.new(RBS.builder.expand_alias2(type.name, type.args)).to_symbolic_call(size: size)
        end
      when ::RBS::Types::Bases::Class
        RaaP.logger.warn("Unresolved `class` type, use Object instead.")
        Object
      when ::RBS::Types::Bases::Instance
        RaaP.logger.warn("Unresolved `instance` type, use Object.new instead.")
        Object.new
      when ::RBS::Types::Bases::Self
        raise "cannot resolve `self` type"
      when ::RBS::Types::ClassSingleton
        Object.const_get(type.name.to_s)
      when ::RBS::Types::ClassInstance
        case gen = GENERATORS[type.name.absolute!.to_s]
        in Proc then pick_by_generator(gen, size: size)
        in nil then to_symbolic_call_from_initialize(type, size: size)
        end
      when ::RBS::Types::Record
        type.fields.transform_values { |t| Type.new(t).to_symbolic_call(size: size / 2) }
      when ::RBS::Types::Proc
        Proc.new { Type.new(type.type.return_type).to_symbolic_call(size: size) }
      when ::RBS::Types::Literal
        type.literal
      when ::RBS::Types::Bases::Bool
        bool
      when ::RBS::Types::Bases::Any
        Type.random.to_symbolic_call(size: size)
      when ::RBS::Types::Bases::Nil
        nil
      else
        raise "not implemented #{type}"
      end
    end

    private

    def pick_by_generator(gen, size:)
      ret = instance_exec(&gen)
      case ret
      when Sized
        ret.pick(size: size)
      else
        ret
      end
    end

    def to_symbolic_call_from_initialize(type, size:)
      type_name = type.name.absolute!
      const = Object.const_get(type_name.to_s)
      Type.call_new_from(const, type, size: size)
    end

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
          high - (Arithmetic.positive_float * size)
        in low, nil
          low + (Arithmetic.positive_float * size)
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
          in [nil, nil]
            size.times.map { SIMPLE_SOURCE.sample }.join
          in [nil, _] | [_, nil]
            raise "Should set range.begin and range.end"
          in [s, e]
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
          type.to_symbolic_call(size: size / 2)
        end
      end
    end

    # Create Hash object. But not `hash`.
    # Avoid to use `hash` since core method name
    def dict(key_type, value_type)
      sized do |size|
        csize = size / 2
        Array.new(integer.pick(size: size).abs).to_h do
          [
            key_type.to_symbolic_call(size: csize),
            value_type.to_symbolic_call(size: csize)
          ]
        end
      end
    end

    def encoding
      e = Encoding.list.sample or raise
      [:call, Encoding, :find, [e.name], {}, nil]
    end

    def bool
      Random.rand(2) == 0
    end

    def temp_method_object
      o = Object.new
      m = 6.times.map { SIMPLE_SOURCE.sample }.join
      o.define_singleton_method(m) {}
      o.method(m)
    end
  end
end
