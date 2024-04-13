# frozen_string_literal: true

module RaaP
  module Result
    module ReturnValueWithType
      def return_value_with_type
        return_type = return_value_to_type(return_value)
        type = if return_type.empty? || return_type == 'nil'
                 ''
               else
                 "[#{return_type}]"
               end
        "#{BindCall.inspect(return_value)}#{type}"
      end

      private

      def return_value_to_type(val)
        case val
        when nil
          'nil'
        when true, false
          "bool"
        when Array
          elem = if val.empty?
                   'untyped'
                 else
                   return_value_to_type(val.first)
                 end
          "Array[#{elem}]"
        when Hash
          key = val.empty? ? 'untyped' : return_value_to_type(val.keys.first)
          value = val.empty? ? 'untyped' : return_value_to_type(val.values.first)
          "Hash[#{key}, #{value}]"
        when Enumerator
          elem =
            begin
              return_value_to_type(val.peek)
            rescue StandardError
              'untyped'
            end
          ret =
            if val.size == Float::INFINITY
              'bot'
            else
              begin
                val.each {}
                   .tap { val.rewind }
                   .then { return_value_to_type(_1) }
              rescue StandardError
                'untyped'
              end
            end
          "Enumerator[#{elem}, #{ret}]"
        else
          "#{BindCall.class(val)}"
        end
      rescue StandardError => e
        RaaP.logger.debug("[#{e.class}] #{e.exception.detailed_message}")
        RaaP.logger.debug(e.exception.backtrace&.join("\n"))
        "raised #{e.class} with check return_type"
      end
    end

    class Success < Data.define(:symbolic_call, :return_value)
      include ReturnValueWithType

      def called_str
        scr = SymbolicCaller.new(symbolic_call)
        "#{scr.call_str} -> #{return_value_with_type}"
      end
    end

    class Failure < Data.define(:symbolic_call, :return_value, :exception)
      include ReturnValueWithType

      def initialize(exception: nil, **)
        super
      end

      def called_str
        scr = SymbolicCaller.new(symbolic_call)
        return_type =
          if exception
            "raised #{exception.class}"
          else
            return_value_with_type
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
