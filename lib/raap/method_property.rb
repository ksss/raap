# frozen_string_literal: true

module RaaP
  class MethodProperty
    class Stats < Struct.new(:success, :skip, :exception, :break, keyword_init: true)
      def initialize(success: 0, skip: 0, exception: 0, break: false)
        super
      end
    end

    def initialize(receiver_type:, method_name:, method_type:, size_step:, timeout:, allow_private: false)
      @receiver_type = receiver_type
      @method_name = method_name
      @method_type = method_type
      @size_step = size_step
      @timeout = timeout
      @allow_private = allow_private
    end

    def run
      stats = Stats.new
      begin
        Timeout.timeout(@timeout) do
          catch(:break) do
            @size_step.each do |size|
              call(size: size, stats: stats).tap do |ret|
                case ret
                when Result::Success
                  stats.success += 1
                when Result::Failure
                  # no count
                when Result::Skip
                  stats.skip += 1
                when Result::Exception
                  stats.exception += 1
                end

                yield ret
              end
            end
          end
        end
      rescue Timeout::Error => exception
        stats.break = true
        RaaP.logger.info "Timeout: #{exception}"
      end
      stats
    end

    private

    def call(size:, stats:)
      if @method_type.rbs.type.each_param.find { |param| param.type.each_type.find { |t| t.instance_of?(::RBS::Types::Bases::Any) } }
        RaaP.logger.info { "Skip type check since `#{@method_type.rbs}` includes `untyped`" }
        stats.break = true
        throw :break
      end
      receiver_value = @receiver_type.to_symbolic_call(size: size)
      args, kwargs, block = @method_type.arguments_to_symbolic_call(size: size)
      # @type var symbolic_call: symbolic_call
      symbolic_call = [:call, receiver_value, @method_name, args, kwargs, block]
      symbolic_caller = SymbolicCaller.new(symbolic_call, allow_private: @allow_private)
      begin
        # ensure symbolic_call
        check = [:failure]
        if return_type.instance_of?(::RBS::Types::Bases::Bottom)
          begin
            return_value = symbolic_caller.eval
          rescue StandardError, NotImplementedError
            return_value = Value::Bottom.new
            coverage("return", return_value, return_type)
            check = [:success]
          rescue Timeout::ExitException
            raise
          rescue Exception => e # rubocop:disable Lint/RescueException
            RaaP.logger.error("[#{e.class}] class is not supported to check `bot` type")
            raise
          end
        else
          return_value = symbolic_caller.eval
          check = check_return(receiver_value: receiver_value, return_value: return_value, annotations: @method_type.annotations)
        end
        case check
        in [:success]
          Result::Success.new(symbolic_call: symbolic_call, return_value: return_value)
        in [:failure]
          Result::Failure.new(symbolic_call: symbolic_call, return_value: return_value)
        in [:exception, exception]
          Result::Exception.new(symbolic_call: symbolic_call, exception: exception)
        end
      rescue TypeError => exception
        Result::Failure.new(symbolic_call: symbolic_call, return_value: return_value, exception: exception)
      end

    # not ensure symbolic_call
    rescue NoMethodError, NotImplementedError => exception
      Result::Skip.new(symbolic_call: symbolic_call, exception: exception)
    rescue NameError => e
      RaaP.logger.warn("[#{e.class}] #{e.detailed_message}")
      msg = e.name.nil? ? '' : "for `#{BindCall.to_s(e.receiver)}::#{e.name}`"
      RaaP.logger.warn("Implementation is not found #{msg} maybe.")
      RaaP.logger.debug(e.backtrace&.join("\n"))
      stats.break = true
      throw :break
    rescue SystemStackError => exception
      RaaP.logger.info "Found recursive type definition."
      Result::Skip.new(symbolic_call: symbolic_call, exception: exception)
    rescue => exception
      Result::Exception.new(symbolic_call: symbolic_call, exception: exception)
    end

    def check_return(receiver_value:, return_value:, annotations:)
      annotations.each do |a|
        case a.string
        when "implicitly-returns-nil"
          if BindCall.is_a?(return_value, NilClass)
            return [:success]
          end
        end
      end

      if BindCall.is_a?(receiver_value, Module)
        if BindCall.is_a?(return_type, ::RBS::Types::ClassSingleton)
          # ::RBS::Test::TypeCheck cannot support to check singleton class
          if receiver_value == return_value
            coverage("return", return_value, return_type)
            [:success]
          else
            [:failure]
          end
        end

        self_class = receiver_value
        instance_class = receiver_value
      else
        self_class = BindCall.class(receiver_value)
        instance_class = BindCall.class(receiver_value)
      end
      type_check = ::RBS::Test::TypeCheck.new(
        self_class: self_class,
        instance_class: instance_class,
        class_class: Module,
        builder: RBS.builder,
        sample_size: 100,
        unchecked_classes: []
      )
      begin
        if type_check.value(return_value, return_type)
          coverage("return", return_value, return_type, type_check)
          [:success]
        else
          [:failure]
        end
      rescue => e
        RaaP.logger.debug("Type check fail by `(#{e.class}) #{e.message}`")
        [:exception, e]
      end
    end

    def return_type
      @method_type.rbs.type.return_type
    end

    def coverage(position, return_value, return_type, type_check = nil)
      return unless Coverage.running?

      case return_type
      when ::RBS::Types::Tuple
        return_type.types.zip(return_value).each_with_index do |(type, value), i|
          if type_check&.value(value, type)
            coverage("#{position}_tuple_#{i}", value, type, type_check)
          end
        end
      when ::RBS::Types::Union
        return_type.types.each_with_index do |type, i|
          if type_check&.value(return_value, type)
            coverage("#{position}_union_#{i}", return_value, type, type_check)
            break
          end
        end
      when ::RBS::Types::Optional
        if return_value.nil?
          Coverage.log("#{position}_optional_right")
        else
          coverage("#{position}_optional_left", return_value, return_type.type, type_check)
        end
      else
        Coverage.log(position)
      end
    end
  end
end
