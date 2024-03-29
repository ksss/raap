# frozen_string_literal: true

module RaaP
  class MethodProperty
    class Stats < Struct.new(:success, :skip, :exception)
      def initialize(success: 0, skip: 0, exception: 0)
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
              yield call(size: size, stats: stats)
            end
          end
        end
      rescue Timeout::Error => exception
        RaaP.logger.warn "Timeout: #{exception}"
      end
      stats
    end

    private

    def call(size:, stats:)
      receiver_value = @receiver_type.pick(size: size, eval: false)
      args, kwargs, block = @method_type.pick_arguments(size: size, eval: false)
      # @type var symbolic_call: symbolic_call
      symbolic_call = [:call, receiver_value, @method_name, args, kwargs, block]
      symbolic_caller = SymbolicCaller.new(symbolic_call, allow_private: @allow_private)
      begin
        # ensure symbolic_call
        check = false
        if return_type.instance_of?(::RBS::Types::Bases::Bottom)
          begin
            return_value = symbolic_caller.eval
          rescue StandardError, NotImplementedError
            check = true
            return_value = Value::Bottom.new
          end
        else
          return_value = symbolic_caller.eval
          check = check_return(receiver_value:, return_value:, method_type: @method_type)
        end
        if check
          stats.success += 1
          Result::Success.new(symbolic_call:, return_value:)
        else
          Result::Failure.new(symbolic_call:, return_value:)
        end
      rescue TypeError => exception
        Result::Failure.new(symbolic_call:, return_value:, exception:)
      end

    # not ensure symbolic_call
    rescue NoMethodError => exception
      stats.skip += 1
      Result::Skip.new(symbolic_call:, exception:)
    rescue NameError => e
      msg = e.name.nil? ? '' : "for `#{BindCall.to_s(e.receiver)}::#{e.name}`"
      RaaP.logger.error("Implementation is not found #{msg} maybe.")
      throw :break
    rescue NotImplementedError => exception
      stats.skip += 1
      Result::Skip.new(symbolic_call:, exception:)
    rescue SystemStackError => exception
      stats.skip += 1
      RaaP.logger.warn "Found recursive type definition."
      Result::Skip.new(symbolic_call:, exception:)
    rescue => exception
      stats.exception += 1
      Result::Exception.new(symbolic_call:, exception:)
    end

    def check_return(receiver_value:, return_value:, method_type:)
      if BindCall.is_a?(receiver_value, Module)
        if BindCall.is_a?(return_type, ::RBS::Types::ClassSingleton)
          # ::RBS::Test::TypeCheck cannot support to check singleton class
          return receiver_value == return_value
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
        type_check.value(return_value, return_type)
      rescue => e
        $stderr.puts "Type check fail by `(#{e.class}) #{e.message}`"
        false
      end
    end

    def return_type
      @method_type.rbs.type.return_type
    end
  end
end
