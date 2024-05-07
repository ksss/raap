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
        type.map { |v| to_symbolic_call_recursive(v, size: size) }
      else
        type.to_symbolic_call(size: size)
      end
    end

    def build_args_type
      reqs = @fun.required_positionals.map.with_index do |param, i|
        build_type_with_coverage("req_#{i}", param)
      end

      take_num = Random.rand(@fun.optional_positionals.length + 1)
      opts = @fun.optional_positionals.take(take_num).map.each_with_index do |param, i|
        build_type_with_coverage("opt_#{i}", param)
      end

      rest = []
      if (rest_param = @fun.rest_positionals)
        rest = Array.new(Random.rand(4)) do
          build_type_with_coverage("rest", rest_param)
        end
      end

      tras = @fun.trailing_positionals.map.with_index do |param, i|
        build_type_with_coverage("trail_#{i}", param)
      end

      [reqs, opts, rest, tras].flatten
    end

    def build_kwargs_type
      reqs = @fun.required_keywords.keys.to_h do |key|
        [key, build_type_with_coverage("keyreq_#{key}", @fun.required_keywords[key])]
      end
      rand = Random.rand(@fun.optional_keywords.length + 1)
      opts = @fun.optional_keywords.to_a.sample(rand).to_h do |key, param|
        [key, build_type_with_coverage("key_#{key}", param)]
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
          [random_key, build_type_with_coverage("keyrest", param)]
        end
        kwargs.merge!(keys.to_h)
      end
      kwargs
    end

    def build_type_with_coverage(position, param)
      Coverage.new_type_with_log(position, param.type)
    end
  end
end
