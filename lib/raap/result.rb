# frozen_string_literal: true

module RaaP
  module Result
    class Success < Data.define(:symbolic_call, :return_value)
      def called_str
        scr = SymbolicCaller.new(symbolic_call)
        return_type =
          case return_value
          when nil then ''
          when true, false then '[bool]'
          else
            "[#{BindCall.class(return_value)}]"
          end
        "#{scr.call_str} -> #{BindCall.inspect(return_value)}#{return_type}"
      end
    end

    class Failure < Data.define(:symbolic_call, :return_value, :exception)
      def initialize(exception: nil, **)
        super
      end

      def called_str
        scr = SymbolicCaller.new(symbolic_call)
        return_type =
          if exception
            "raised #{exception.class}"
          else
            case return_value
            when nil then 'nil'
            when true, false then "#{BindCall.inspect(return_value)}[bool]"
            else
              "#{BindCall.inspect(return_value)}[#{BindCall.class(return_value)}]"
            end
          end
        "#{scr.call_str} -> #{return_type}"
      end
    end

    class Skip < Data.define(:symbolic_call, :exception)
    end

    class Exception < Data.define(:symbolic_call, :exception)
    end
  end
end
