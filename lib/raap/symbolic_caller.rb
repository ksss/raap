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
    class Var
      attr_reader :name
      def initialize(name)
        @name = name
      end

      def +(other)
        "#{self}#{other}"
      end

      def to_s
        @name
      end
    end

    attr_reader :symbolic_call

    def initialize(symbolic_call, allow_private: false)
      @symbolic_call = symbolic_call
      @allow_private = allow_private
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

          case
          when receiver_value == Kernel
            var = Var.new(method_name.to_s.downcase)
            var_eq = "#{var} = "
            receiver = ''
          when BindCall.instance_of?(receiver_value, Var)
            var_eq = ""
            var = Var.new(receiver_value.name)
            receiver = var + '.'
          when is_mod
            var = Var.new(var_name(receiver_value))
            var_eq = "#{var} = "
            receiver = receiver_value.name + '.'
          else
            var_eq = ""
            receiver = if printable?(receiver_value)
              var = Var.new(printable(receiver_value))
              var + '.'
            else
              var = Var.new(var_name(receiver_value.class))
              var + '.'
            end
          end

          arguments = []
          arguments << args.map { |a| printable(a) } if !args.empty?
          arguments << kwargs.map{|k,v| "#{k}: #{printable(v)}" }.join(', ') if !kwargs.empty?
          block_str = block ? " { }" : ""

          lines << "#{var_eq}#{receiver}#{method_name}(#{arguments.join(', ')})#{block_str}"

          var
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
      in Var
        symbolic_call.name
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
      if @allow_private
        receiver_value.__send__(method_name, *args, **kwargs, &block)
      else
        BindCall.public_send(receiver_value, method_name, *args, **kwargs, &block)
      end
    end

    def var_name(mod)
      printable(mod).gsub('::', '_').downcase
    end

    def printable?(obj)
      case obj
      when Symbol, Integer, Float, Regexp, nil, true, false, String, Module, Var, Array
        true
      else
        false
      end
    end

    def printable(obj)
      case obj
      when Var
        obj.name
      # Object from which it can get strings that can be eval with `#inspect`
      when Symbol, Integer, Float, Regexp, nil, true, false
        obj.inspect
      when String
        obj.inspect.gsub('"', "'") or raise
      when Array
        "[#{obj.map { |o| printable(o) }.join(', ')}]"
      when Module
        BindCall.name(obj) or raise
      else
        var_name(obj.class)
      end
    end
  end
end
