# frozen_string_literal: true

module RaaP
  class FunctionType
    def initialize(fun)
      @fun = fun
    end

    def pick_arguments(size: 10, eval: true)
      a = recursive_pick(build_args_type, size:, eval:)
      k = recursive_pick(build_kwargs_type, size:, eval:)

      [a, k]
    end

    private

    def recursive_pick(type, size:, eval:)
      case
      when type.nil?
        nil
      when type.respond_to?(:each_pair)
        type.each_pair.to_h { |k, v| [k, recursive_pick(v, size:, eval:)] }
      when type.respond_to?(:each)
        type.each.map { |v| recursive_pick(v, size:, eval:) }
      else
        type.pick(size:, eval:)
      end
    end

    def build_args_type
      reqs = @fun.required_positionals.map { |param| Type.new(param.type) }
      tras = @fun.trailing_positionals.map { |param| Type.new(param.type) }
      sampled_optional_positionals = @fun.optional_positionals.sample(Random.rand(@fun.optional_positionals.length + 1))
      opts = sampled_optional_positionals.map { |param| Type.new(param.type) }
      rest = []
      if param = @fun.rest_positionals
        rest = Array.new(Random.rand(0..3)) { Type.new(param.type) }
      end
      [reqs, opts, rest, tras].flatten
    end

    def build_kwargs_type
      reqs = @fun.required_keywords.transform_values { |param| Type.new(param.type) }
      rand = Random.rand(@fun.optional_keywords.length + 1)
      opts = @fun.optional_keywords.to_a.sample(rand).to_h { |name, param| [name, Type.new(param.type)] }
      kwargs = reqs.to_h.merge(opts)
      if param = @fun.rest_keywords
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
