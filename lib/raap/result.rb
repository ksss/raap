# frozen_string_literal: true

module RaaP
  module Result
    module ReturnValueWithType
      def return_value_with_type
        return_type = case return_value
                      when nil
                        ''
                      when true, false
                        "[bool]"
                      when Enumerator
                        elem = begin
                          return_value.peek
                        rescue StopIteration
                          nil
                        end
                        ret = if return_value.size == Float::INFINITY
                                nil
                              else
                                return_value.each {
                                  # empty
                                }.tap { return_value.rewind }
                              end
                        "[Enumerator[#{BindCall.class(elem)}, #{BindCall.class(ret)}]]"
                      else
                        "[#{BindCall.class(return_value)}]"
                      end
        "#{BindCall.inspect(return_value)}#{return_type}"
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
