# frozen_string_literal: true

module RaaP
  # sc = SymbolicCaller.new(
  #   [:call,
  #     [:call, C, :new, [], {
  #       a: [:call, A, :new, [], {}, nil],
  #       b: [:call, B, :new, [], {}, nil] }, nil],
  #     :run, [], {}, nil]
  # sc.eval #=> 123
  #
  # sc.to_lines
  # ↓
  # a = A.new(1)
  # b = B.new(b: 'bbb')
  # c = C.new(a: a, b: b)
  # c.run() { }
  class SymbolicCaller
    attr_reader :symbolic_call

    def initialize(symbolic_call)
      @symbolic_call = symbolic_call
    end

    def eval
      walk do |symbolic_call|
        eval_one(symbolic_call)
      end
    end

    def walk(&)
      _walk(@symbolic_call, &)
    end

    def to_lines
      [].tap do |lines|
        walk do |symbolic_call|
          symbolic_call => [:call, receiver_value, method_name, args, kwargs, block]

          is_mod = receiver_value.is_a?(Module)

          if receiver_value == Kernel
            var = "#{var_name(method_name)} = "
            receiver = ''
          elsif is_mod
            var = "#{var_name(receiver_value)} = "
            receiver = receiver_value.name + '.'
          else
            var = ""
            receiver = if printable?(receiver_value)
              printable(receiver_value) + '.'
            else
              var_name(receiver_value.class) + '.'
            end
          end

          arguments = []
          arguments << args.map { |a| printable(a) } if !args.empty?
          arguments << kwargs.map{|k,v| "#{k}: #{printable(v)}" }.join(', ') if !kwargs.empty?
          block_str = block ? " { }" : ""

          lines << "#{var}#{receiver}#{method_name}(#{arguments.join(', ')})#{block_str}"

          eval_one(symbolic_call)
        end
      end
    end

    private

    def _walk(symbolic_call, &block)
      return symbolic_call if BindCall::instance_of?(symbolic_call, BasicObject)
      return symbolic_call if !BindCall.respond_to?(symbolic_call, :deconstruct) && !BindCall.respond_to?(symbolic_call, :deconstruct_keys)

      case symbolic_call
      in [:call, receiver, Symbol => method_name, Array => args, Hash => kwargs, b]
        receiver = _walk(receiver, &block)
        args = _walk(args, &block) if !args.empty?
        kwargs = _walk(kwargs, &block) if !kwargs.empty?
        block.call [:call, receiver, method_name, args, kwargs, b]
      in Array
        symbolic_call.map { |sc| _walk(sc, &block) }
      in Hash
        symbolic_call.transform_values { |sc| _walk(sc, &block) }
      else
        symbolic_call
      end
    end

    def eval_one(symbolic_call)
      symbolic_call => [:call, receiver_value, method_name, args, kwargs, block]

      begin
        receiver_value.__send__(method_name, *args, **kwargs, &block)
      rescue => e
        RaaP.logger.error("Cannot eval symbolic call #{symbolic_call} with #{e.class}")
        raise
      end
    end

    def var_name(mod)
      printable(mod).gsub('::', '_').downcase
    end

    def printable?(obj)
      case obj
      when Symbol, Integer, Float, Regexp, nil, true, false, String, Module
        true
      else
        false
      end
    end

    def printable(obj)
      case obj
      # Object from which it can get strings that can be eval with `#inspect`
      when Symbol, Integer, Float, Regexp, nil, true, false
        obj.inspect
      when String
        obj.inspect.gsub('"', "'") or raise
      when Module
        BindCall.name(obj) or raise
      else
        var_name(obj.class)
      end
    end
  end
end
