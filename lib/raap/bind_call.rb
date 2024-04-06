module RaaP
  module BindCall
    class << self
      def define_singleton_method(...) = ::Object.instance_method(:define_singleton_method).bind_call(...)
      def respond_to?(...) = ::Kernel.instance_method(:respond_to?).bind_call(...)
      def instance_of?(...) = ::Kernel.instance_method(:instance_of?).bind_call(...)
      def is_a?(...) = ::Kernel.instance_method(:is_a?).bind_call(...)
      def extend(...) = ::Kernel.instance_method(:extend).bind_call(...)
      def name(...) = ::Module.instance_method(:name).bind_call(...)
      def to_s(...) = ::Kernel.instance_method(:to_s).bind_call(...)
      def public_send(...) = ::Kernel.instance_method(:public_send).bind_call(...)

      def class(obj)
        if instance_of?(obj, BasicObject)
          ::Kernel.instance_method(:class).bind_call(obj)
        else
          obj.class
        end
      end

      def inspect(obj)
        if instance_of?(obj, BasicObject)
          ::Kernel.instance_method(:inspect).bind_call(obj)
        else
          case obj
          when Hash
            body = obj.map do |k, v|
              "#{inspect(k)} => #{inspect(v)}"
            end
            "{#{body.join(', ')}}"
          when Array
            "[#{obj.map { |o| inspect(o) }.join(', ')}]"
          else
            obj.inspect
          end
        end
      rescue NoMethodError
        "#<#{self.class(obj)}>"
      end
    end
  end
end
