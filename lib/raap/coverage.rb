# frozen_string_literal: true

module RaaP
  module Coverage
    class Writer
      def initialize(method_type, green_locs)
        @method_type = method_type
        @green_locs = green_locs
      end

      def write(io)
        if (found = @method_type.each_type.find { |type| type.location.nil? })
          RaaP.logger.info("Cannot show coverage, Because location of #{found} is nil")
          return
        end

        location = @method_type.location or raise
        @cur = location.start_loc
        @method_type.type.yield_self do |fun|
          case fun
          when ::RBS::Types::Function
            fun.required_positionals.each    { |param| write_param(io, param, :abs) }
            fun.optional_positionals.each    { |param| write_param(io, param, :opt) }
            fun.rest_positionals&.yield_self { |param| write_param(io, param, :opt) }
            fun.trailing_positionals.each    { |param| write_param(io, param, :abs) }
            fun.required_keywords.each_value { |param| write_param(io, param, :abs) }
            fun.optional_keywords.each_value { |param| write_param(io, param, :opt) }
            fun.rest_keywords&.yield_self    { |param| write_param(io, param, :opt) }
            # when ::RBS::Types::UntypedFunction
          end
        end
        @method_type.block&.yield_self do |b|
          b.type.each_param { |param| write_param(io, param, :opt) }
          write_type(io, b.type.return_type, b.type.return_type.location, :abs)
          # write_type(io, b.self_type) if b.self_type
        end
        write_type(io, @method_type.type.return_type, @method_type.type.return_type.location, :abs)

        io.write(slice_by_loc(@cur, location.end_loc))
        io.puts
      end

      private

      def slice_by_loc(a, b)
        location = @method_type.location or raise
        mloc = location.start_loc
        lines = location.source.lines
        start_pos = lines.take(a[0] - mloc[0]).inject(0) { |r, line| r + line.length } + (a[1])
        start_pos -= mloc[1] if a[0] == mloc[0]
        end_pos = lines.take(b[0] - mloc[0]).inject(0) { |r, line| r + line.length } + (b[1])
        end_pos -= mloc[1] if b[0] == mloc[0]
        location.source[start_pos...end_pos] or raise
      end

      def write_param(io, param, accuracy)
        param.location or raise
        write_type(io, param.type, param.location, accuracy)
      end

      def write_type(io, type, location, accuracy)
        io.write(slice_by_loc(@cur, location.start_loc))
        @cur = location.start_loc
        case type
        when ::RBS::Types::Tuple, ::RBS::Types::Union
          type.types.each do |t|
            t.location or raise
            io.write(slice_by_loc(@cur, t.location.start_loc))
            @cur = t.location.end_loc
            write_type(io, t, t.location, accuracy)
          end
        when ::RBS::Types::Optional
          type.type.location or raise
          sliced_loc = type.location.dup
          sliced_loc.tap do |s|
            s = __skip__ = s
            # FIXME: Hackish, cut 1 character from back.
            s.source
            s.instance_eval { @source = @source[0...-1] }
            s.end_loc
            s.instance_eval { @end_loc = [@end_loc[0], @end_loc[1] - 1] }
          end
          write_type(io, type.type, sliced_loc, accuracy)
          if @green_locs.include?([location.end_loc.dup.tap { _1[1] -= 1 }, location.end_loc])
            io.write(green('?'))
          else
            io.write(red('?'))
          end
          @cur = location.end_loc
        when ::RBS::Types::Variable
          case accuracy
          when :abs
            io.write(green(type.name.to_s))
          when :opt
            # Variables are substed so raap don't know if they've been used.
            io.write(yellow(type.name.to_s))
          end
          @cur = location.end_loc
        else
          if @green_locs.include?([location.start_loc, location.end_loc])
            io.write(green(location.source))
          else
            io.write(red(location.source))
          end
          @cur = location.end_loc
        end
      end

      def green(str) = "\e[32m#{str}\e[0m"
      def red(str) = "\e[1;4;41m#{str}\e[0m"
      def yellow(str) = "\e[93m#{str}\e[0m"
    end

    Log = Data.define(:name, :locs)

    class << self
      def start(method_type)
        @logs = []
        @method_type = method_type
        if @method_type.location.nil?
          @logs = nil
        end
      end

      def running?
        !!@logs
      end

      def log(name:, locs:)
        return unless running?

        @logs << Log.new(name: name, locs: locs)
      end

      def logs
        @logs
      end

      def show(io)
        return unless running?

        writer = Writer.new(@method_type, green_locs)
        writer.write(io)
      end

      private

      def green_locs
        @logs.select { |log| log.name == @method_type.location.buffer.name }
             .map(&:locs)
             .sort
             .to_set
      end
    end
  end
end
