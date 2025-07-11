# frozen_string_literal: true

module RaaP
  # $ raap Integer#pow
  class CLI
    Option = Struct.new(
      :dirs,
      :requires,
      :libraries,
      :timeout,
      :size_from,
      :size_to,
      :size_by,
      :allow_private,
      :coverage,
      :numeric_positive,
      keyword_init: true
    )

    # Should skip methods has side effects
    DEFAULT_SKIP = Set.new
    %i[
      fork system exec spawn `
      abort exit exit! raise fail
      load require require_relative
      gem
    ].each do |kernel_method|
      DEFAULT_SKIP << "::Kernel##{kernel_method}"
      DEFAULT_SKIP << "::Kernel.#{kernel_method}"
    end
    %i[
      delete unlink chmod lchmod chown lchown
      link mkfifo new open rename truncate
    ].each { |m| DEFAULT_SKIP << "::File.#{m}" }
    %i[flock truncate].each { |m| DEFAULT_SKIP << "::File##{m}" }

    attr_accessor :option, :argv, :skip, :results

    def initialize(argv)
      # defaults
      @option = Option.new(
        timeout: 3,
        size_from: 0,
        size_to: 99,
        size_by: 1,
        coverage: true,
        allow_private: false,
        numeric_positive: false,
      )
      @argv = argv
      @skip = DEFAULT_SKIP.dup
      @results = []
    end

    def load
      OptionParser.new do |o|
        o.version = RaaP::VERSION

        o.on('-I', '--include PATH') do |path|
          RaaP::RBS.loader.add(path: Pathname(path))
        end
        o.on('--library lib', 'load rbs library') do |lib|
          RaaP::RBS.loader.add(library: lib, version: nil)
        end
        o.on('--require lib', 'require ruby library') do |lib|
          require lib
        end
        o.on('--log-level level', "default: info") do |arg|
          RaaP.logger.level = arg
        end
        o.on('--timeout sec', Float, "default: #{@option.timeout}") do |arg|
          @option.timeout = arg
        end
        o.on('--size-from int', Integer, "default: #{@option.size_from}") do |arg|
          @option.size_from = arg
        end
        o.on('--size-to int', Integer, "default: #{@option.size_to}") do |arg|
          @option.size_to = arg
        end
        o.on('--size-by int', Integer, "default: #{@option.size_by}") do |arg|
          @option.size_by = arg
        end
        o.on('--allow-private', "default: #{@option.allow_private}") do
          @option.allow_private = true
        end
        o.on('--preload path', 'Kernel.load path') do |path|
          Kernel.load path
        end
        o.on('--[no-]coverage', "Show coverage for RBS (default: #{@option.coverage})") do |arg|
          @option.coverage = arg
        end
        o.on('--numeric-positive', "Generate positive numeric only (default: #{@option.numeric_positive})") do |arg|
          @option.numeric_positive = arg
        end
      end.parse!(@argv)

      self
    end

    def run
      Signal.trap(:INT) do
        puts "Interrupted by SIGINT"
        report
        exit 1
      end

      # Search skip tag
      @argv.each do |tag|
        if tag.start_with?('!')
          t = tag[1..] or raise
          t = "::#{t}" unless t.start_with?('::')
          t or raise
          @skip << t
        end
      end
      @skip.freeze

      Type::Arithmetic.numeric_positive = @option.numeric_positive

      @argv.each do |tag|
        next if tag.start_with?('!')

        case
        when tag.include?('#')
          run_by(kind: :instance, tag:)
        when tag.include?('.')
          run_by(kind: :singleton, tag:)
        when tag.end_with?('*')
          run_by_type_name_with_search(tag:)
        else
          run_by_type_name(tag:)
        end
      end

      report
    end

    private

    def report
      i = 0
      exit_status = 0
      @results.each do |ret|
        ret => { method:, properties: }
        properties.select { |status,| status == 1 }.each do |_, method_name, method_type, reason|
          i += 1
          location = if method.alias_of
                       alias_decl = RBS.find_alias_decl(method.defined_in, method_name) or raise "alias decl not found: #{method_name}"
                       alias_decl.location
                     else
                       method_type.location
                     end
          prefix = method.defs.first.member.kind == :instance ? '' : 'self.'

          puts "\e[41m\e[1m#\e[m\e[1m #{i}) Failure:\e[m"
          puts
          puts "def #{prefix}#{method_name}: #{method_type}"
          puts "  in #{location}"
          puts
          puts "## Reason"
          puts
          puts reason&.string
          puts
          exit_status = 1
        end
      end
      exit_status
    end

    def run_by(kind:, tag:)
      split = kind == :instance ? '#' : '.'
      t, m = tag.split(split, 2)
      t or raise
      m or raise
      type = RBS.parse_type(t)
      raise "cannot specified #{type.class}" unless type.respond_to?(:name)

      type = __skip__ = type
      type_name = type.name.absolute!
      type_to_s = type.to_s.start_with?('::') ? type.to_s : "::#{type}"
      receiver_type = if kind == :instance
                        Type.new(type_to_s)
                      else
                        Type.new("singleton(#{type_name})")
                      end
      method_name = m.to_sym
      definition = if kind == :instance
                     RBS.builder.build_instance(type_name)
                   else
                     RBS.builder.build_singleton(type_name)
                   end

      method = definition.methods[method_name]
      raise "`#{tag}` not found" unless method

      if @skip.include?("#{type_name}#{split}#{method_name}")
        raise "`#{type_name}#{split}#{method_name}` is a method to be skipped"
      end

      type_params_decl = definition.type_params_decl
      type_args = type.args

      RaaP.logger.info("# #{type}")
      @results << {
        method:,
        properties: method.defs.map do |type_def|
          property(
            receiver_type:,
            type_params_decl:,
            type_args:,
            type_def:,
            method_name:
          )
        end
      }
    end

    def run_by_type_name_with_search(tag:)
      first, _last = tag.split('::')
      RBS.env.class_decls.each do |name, _entry|
        if ['', '::'].any? { |pre| name.to_s.start_with?("#{pre}#{first}") }
          if @skip.include?(name.to_s)
            RaaP.logger.info("Skip #{name}")
            next
          end
          run_by_type_name(tag: name.to_s)
        end
      end
    end

    def run_by_type_name(tag:)
      type = RBS.parse_type(tag)
      type = __skip__ = type
      raise "cannot specified #{type.class}" unless type.respond_to?(:name)

      type_name = type.name.absolute!
      type_args = type.args

      definition = RBS.builder.build_singleton(type_name)
      type_params_decl = definition.type_params_decl.freeze
      definition.methods.each do |method_name, method|
        if @skip.include?("#{type_name.absolute!}.#{method_name}")
          RaaP.logger.info("Skip #{"#{type_name.absolute!}.#{method_name}"}")
          next
        end
        next unless method.accessibility == :public
        next if method.defined_in != type_name

        RaaP.logger.info("# #{type_name}.#{method_name}")
        @results << {
          method:,
          properties: method.defs.map do |type_def|
            property(
              receiver_type: Type.new("singleton(#{type.name})"),
              type_params_decl:,
              type_args:,
              type_def:,
              method_name:
            )
          end
        }
      end

      definition = RBS.builder.build_instance(type_name)
      type_params_decl = definition.type_params_decl.freeze
      definition.methods.each do |method_name, method|
        if @skip.include?("#{type_name.absolute!}##{method_name}")
          RaaP.logger.info("Skip #{"#{type_name.absolute!}.#{method_name}"}")
          next
        end
        next unless method.accessibility == :public
        next if method.defined_in != type_name

        RaaP.logger.info("# #{type_name}##{method_name}")
        @results << {
          method:,
          properties: method.defs.map do |type_def|
            property(
              receiver_type: Type.new(type.name),
              type_params_decl:,
              type_args:,
              type_def:,
              method_name:
            )
          end
        }
      end
    end

    def property(receiver_type:, type_params_decl:, type_args:, type_def:, method_name:)
      rtype = __skip__ = receiver_type.type
      if receiver_type.type.instance_of?(::RBS::Types::ClassSingleton)
        prefix = 'self.'
      else
        prefix = ''
      end

      # type_args delegate to self_type
      if rtype.instance_of?(::RBS::Types::ClassInstance)
        args = type_params_decl.map.with_index do |param, i|
          type_args[i] || param.upper_bound || ::RBS::Types::Bases::Any.new(location: nil)
        end
        rtype = ::RBS::Types::ClassInstance.new(name: rtype.name, args:, location: rtype.location)
        receiver_type = Type.new(rtype)
      end
      annotations = type_def.each_annotation.to_a
      if !annotations.empty?
        RaaP.logger.info("## #{annotations.map { |a| "%a{#{a.string}}" }.join(' ')}")
      end
      RaaP.logger.info("## def #{prefix}#{method_name}: #{type_def.type}")
      status = 0
      reason = nil
      prop = MethodProperty.new(
        receiver_type:,
        method_name:,
        method_type: MethodType.new(
          type_def.type,
          type_params_decl:,
          type_args:,
          self_type: rtype,
          instance_type: ::RBS::Types::ClassInstance.new(name: rtype.name, args: type_args, location: nil),
          class_type: ::RBS::Types::ClassSingleton.new(name: rtype.name, location: nil),
        ),
        size_step: @option.size_from.step(to: @option.size_to, by: @option.size_by),
        timeout: @option.timeout,
        allow_private: @option.allow_private,
        annotations:
      )
      RaaP::Coverage.start(type_def.type) if @option.coverage
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stats = prop.run do |called|
        case called
        in Result::Success => s
          print '.'
          RaaP.logger.debug { "Success: #{s.called_str}" }
        in Result::Failure => f
          print 'F'
          if (e = f.exception)
            RaaP.logger.info { "Failure: [#{e.class}] #{e.message}" }
            RaaP.logger.debug { e.backtrace.join("\n") }
          end
          RaaP.logger.debug { PP.pp(f.symbolic_call, ''.dup) }
          reason = StringIO.new
          begin
            reason.puts "Failed in case of `#{f.called_str}`"
            reason.puts
          rescue => e
            RaaP.logger.debug { "Raised `#{e}` in Result::Failure" }
          end
          reason.puts "### Repro"
          reason.puts
          reason.puts "```rb"
          reason.puts SymbolicCaller.new(f.symbolic_call).to_lines.join("\n")
          reason.puts "```"
          status = 1
          throw :break
        in Result::Skip => s
          print 'S'
          RaaP.logger.debug { "\n```\n#{SymbolicCaller.new(s.symbolic_call).to_lines.join("\n")}\n```" }
          RaaP.logger.debug("Skip: #{s.exception.detailed_message}")
          RaaP.logger.debug(s.exception.backtrace.join("\n"))
        in Result::Exception => e
          print 'E'
          RaaP.logger.debug { "\n```\n#{SymbolicCaller.new(e.symbolic_call).to_lines.join("\n")}\n```" }
          RaaP.logger.debug("Exception: #{e.exception.detailed_message}")
          RaaP.logger.debug(e.exception.backtrace.join("\n"))
        end
      end
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      puts
      RaaP::Coverage.show($stdout) if @option.coverage

      time_diff = end_time - start_time
      time = ", time: #{(time_diff * 1000).round}ms"
      stats_log = "success: #{stats.success}, skip: #{stats.skip}, exception: #{stats.exception}#{time}"
      RaaP.logger.info(stats_log)
      puts

      if status == 0 && stats.success.zero? && !stats.break
        status = 1
        reason = StringIO.new
        reason.puts "Never succeeded => #{stats_log}"
      end

      [status, method_name, type_def.type, reason]
    end
  end
end
