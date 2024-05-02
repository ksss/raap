# frozen_string_literal: true

module RaaP
  class FunctionType
    def initialize(fun)
      @fun = fun
    end

    def pick_arguments(size: 10)
      SymbolicCaller.new(arguments_to_symbolic_call(size: size)).eval
    end

    def arguments_to_symbolic_call(size: 10)
      a = to_symbolic_call_recursive(build_args_type, size: size)
      k = to_symbolic_call_recursive(build_kwargs_type, size: size)

      [a, k]
    end

    private

    def to_symbolic_call_recursive(type, size:)
      case
      when type.nil?
        nil
      when type.respond_to?(:each_pair)
        type.each_pair.to_h { |k, v| [k, to_symbolic_call_recursive(v, size: size)] }
      when type.respond_to?(:each)
        type.each.map { |v| to_symbolic_call_recursive(v, size: size) }
      else
        type.to_symbolic_call(size: size)
      end
    end

    def build_args_type
      reqs = @fun.required_positionals.map do |param|
        build_type_with_coverage(param)
      end
      tras = @fun.trailing_positionals.map do |param|
        build_type_with_coverage(param)
      end

      take_num = Random.rand(@fun.optional_positionals.length + 1)
      opts = []
      @fun.optional_positionals.each_with_index do |param, i|
        if i < take_num
          opts << build_type_with_coverage(param)
        end
      end

      rest = []
      if (param = @fun.rest_positionals)
        rest = Array.new(Random.rand(4)) { build_type_with_coverage(param) }
      end

      [reqs, opts, rest, tras].flatten
    end

    def build_kwargs_type
      reqs = @fun.required_keywords.transform_values do |param|
        build_type_with_coverage(param)
      end
      rand = Random.rand(@fun.optional_keywords.length + 1)
      opts = @fun.optional_keywords.to_a.sample(rand).to_h do |name, param|
        [name, build_type_with_coverage(param)]
      end
      kwargs = reqs.to_h.merge(opts)
      if (param = @fun.rest_keywords)
        keys = Array.new(Random.rand(4)) do
          random_key = nil
          loop do
            # @type var random_key: Symbol
            random_key = Type.new("Symbol").pick(size: 6)
            break unless kwargs.key?(random_key)
          end
          [random_key, build_type_with_coverage(param)]
        end
        kwargs.merge!(keys.to_h)
      end
      kwargs
    end

    def build_type_with_coverage(param)
      case param.type
      when ::RBS::Types::Optional
        if Random.rand(2).zero?
          # value
          if param.type.location
            Coverage.log(name: param.type.location.buffer.name, locs: [
              param.type.location.start_loc,
              param.type.location.end_loc.dup.tap { _1[1] -= 1 },
            ])
          end
          Type.new(param.type.type)
        else
          # nil
          if param.type.location
            Coverage.log(name: param.type.location.buffer.name, locs: [
              param.type.location.end_loc.dup.tap { _1[1] -= 1 },
              param.type.location.end_loc,
            ])
          end
          Type.new(::RBS::Types::Bases::Nil.new(location: nil))
        end
      when ::RBS::Types::Union
        t = param.type.types.sample or raise
        if t.location
          Coverage.log(name: t.location.buffer.name, locs: [
            t.location.start_loc,
            t.location.end_loc
          ])
        end
        Type.new(t)
      else
        if param.location
          Coverage.log(name: param.location.buffer.name, locs: [
            param.location.start_loc,
            param.location.end_loc
          ])
        end
        Type.new(param.type)
      end
    end
  end
end
