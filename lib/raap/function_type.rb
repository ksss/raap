# frozen_string_literal: true

module RaaP
  class FunctionType
    def initialize(fun)
      @fun = fun
    end

    def pick_arguments(size: 10)
      SymbolicCaller.new(arguments_to_symbolic_call(size:)).eval
    end

    def arguments_to_symbolic_call(size: 10)
      a = to_symbolic_call_recursive(build_args_type, size:)
      k = to_symbolic_call_recursive(build_kwargs_type, size:)

      [a, k]
    end

    private

    def to_symbolic_call_recursive(type, size:)
      case
      when type.nil?
        nil
      when type.respond_to?(:each_pair)
        type.each_pair.to_h { |k, v| [k, to_symbolic_call_recursive(v, size:)] }
      when type.respond_to?(:each)
        type.each.map { |v| to_symbolic_call_recursive(v, size:) }
      else
        type.to_symbolic_call(size:)
      end
    end

    def build_args_type
      reqs = @fun.required_positionals.map { |param| Type.new(param.type) }
      tras = @fun.trailing_positionals.map { |param| Type.new(param.type) }
      sampled_optional_positionals = @fun.optional_positionals.take(Random.rand(@fun.optional_positionals.length + 1))
      opts = sampled_optional_positionals.map { |param| Type.new(param.type) }
      rest = []
      if (param = @fun.rest_positionals)
        rest = Array.new(Random.rand(0..3)) { Type.new(param.type) }
      end
      [reqs, opts, rest, tras].flatten
    end

    def build_kwargs_type
      reqs = @fun.required_keywords.transform_values { |param| Type.new(param.type) }
      rand = Random.rand(@fun.optional_keywords.length + 1)
      opts = @fun.optional_keywords.to_a.sample(rand).to_h { |name, param| [name, Type.new(param.type)] }
      kwargs = reqs.to_h.merge(opts)
      if (param = @fun.rest_keywords)
        keys = Array.new(Random.rand(0..3)) do
          random_key = nil
          loop do
            # @type var random_key: Symbol
            random_key = Type.new("Symbol").pick(size: 6)
            break unless kwargs.key?(random_key)
          end
          [random_key, Type.new(param.type)]
        end
        kwargs.merge!(keys.to_h)
      end
      kwargs
    end
  end
end
