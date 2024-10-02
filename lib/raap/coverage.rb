# frozen_string_literal: true

module RaaP
  module Coverage
    class Writer
      def initialize(method_type, cov)
        @method_type = method_type
        @cov = cov
        @cur = 0
      end

      def write(io)
        RaaP.logger.debug { "Coverage: #{@cov}" }
        ml = @method_type.location
        unless ml
          RaaP.logger.warn("No location information for `#{@method_type}`")
          return
        end
        if ml.key?(:keyword)
          # attr_{reader,writer,accessor}
          phantom_member = RBS.parse_member(ml.source)
          case phantom_member
          when ::RBS::AST::Members::Attribute
            unless phantom_member.location
              RaaP.logger.warn("No location information for `#{phantom_member}`")
              return
            end
            write_type(io, "return", phantom_member.type)
            io.write(slice(@cur, @cur...phantom_member.location.end_pos))
          else
            RaaP.logger.error("#{phantom_member.class} is not supported")
            return
          end
        else
          # def name: () -> type
          phantom_method_type = RBS.parse_method_type(ml.source)
          phantom_method_type.type.yield_self do |fun|
            case fun
            when ::RBS::Types::Function
              fun.required_positionals.each_with_index { |param, i| write_param(io, "req_#{i}", param) }
              fun.optional_positionals.each_with_index { |param, i| write_param(io, "opt_#{i}", param) }
              fun.rest_positionals&.yield_self         { |param| write_param(io, "rest", param) }
              fun.trailing_positionals.each_with_index { |param, i| write_param(io, "trail_#{i}", param) }
              fun.required_keywords.each               { |key, param| write_param(io, "keyreq_#{key}", param) }
              fun.optional_keywords.each               { |key, param| write_param(io, "key_#{key}", param) }
              fun.rest_keywords&.yield_self            { |param| write_param(io, "keyrest", param) }
              # when ::RBS::Types::UntypedFunction
            end
          end

          phantom_method_type.block&.yield_self do |b|
            b.type.each_param.with_index { |param, i| write_param(io, "block_param_#{i}", param) }
            write_type(io, "block_return", b.type.return_type)
          end
          write_type(io, "return", phantom_method_type.type.return_type)
          raise unless phantom_method_type.location

          io.write(slice(@cur, @cur...phantom_method_type.location.end_pos))
        end

        io.puts
      end

      private

      def slice(start, range)
        ml = @method_type.location
        raise unless ml

        ml.source[start, range.end - range.begin] or raise
      end

      def write_param(io, position, param)
        write_type(io, position, param.type)
      end

      def write_type(io, position, type)
        unless type.location
          RaaP.logger.warn("No location information for `#{type}`")
          return
        end
        io.write(slice(@cur, @cur...type.location.start_pos))
        @cur = type.location.start_pos
        case type
        when ::RBS::Types::Tuple, ::RBS::Types::Union
          cname = type.class.name or raise
          name = cname.split('::').last.downcase
          type.types.each_with_index do |t, i|
            t.location or raise
            io.write(slice(@cur, @cur...t.location.start_pos)) # ( or [
            @cur = t.location.start_pos
            write_type(io, "#{position}_#{name}_#{i}", t)
          end
        when ::RBS::Types::Optional
          raise unless type.location

          write_type(io, "#{position}_optional_left", type.type)
          io.write(slice(@cur, @cur...(type.location.end_pos - 1)))
          @cur = type.location.end_pos - 1
          if @cov.include?("#{position}_optional_right".to_sym)
            io.write(green('?'))
          else
            io.write(red('?'))
          end
          raise unless type.location

          @cur = type.location.end_pos
        else
          raise unless type.location

          if @cov.include?(position.to_sym)
            io.write(green(type.location.source))
          else
            io.write(red(type.location.source))
          end
          @cur = type.location.end_pos
        end
      end

      def green(str) = "\e[32m#{str}\e[0m"
      def red(str) = "\e[1;4;41m#{str}\e[0m"
    end

    class << self
      def start(method_type)
        @cov = Set.new
        @method_type = method_type
      end

      def running?
        !!@cov
      end

      def log(position)
        return unless running?

        cov << position.to_sym
      end

      def cov
        @cov or raise("Coverage is not started")
      end

      def show(io)
        return unless running?

        writer = Writer.new(@method_type, cov)
        writer.write(io)
      end

      def new_type_with_log(position, type)
        log_with_type(position, type) do |t|
          Type.new(t)
        end
      end

      def log_with_type(position, type, &block)
        case type
        when ::RBS::Types::Tuple
          # FIXME: Support Union in Tuple
          type.types.each_with_index do |_t, i|
            log("#{position}_tuple_#{i}")
          end
          block&.call(type)
        when ::RBS::Types::Union
          i = Random.rand(type.types.length)
          log_with_type("#{position}_union_#{i}", type.types[i], &block)
        when ::RBS::Types::Optional
          if Random.rand(2).zero?
            log_with_type("#{position}_optional_left", type.type, &block)
          else
            log_with_type("#{position}_optional_right", ::RBS::Types::Bases::Nil.new(location: nil), &block)
          end
        else
          log(position)
          block&.call(type)
        end
      end
    end
  end
end
