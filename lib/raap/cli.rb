# frozen_string_literal: true

module RaaP
  # $ raap Integer#pow
  class CLI
    class << self
      attr_accessor :option
    end

    Option = Struct.new(
      :dirs,
      :requires,
      :libraries,
      :timeout,
      :size_from,
      :size_to,
      :size_by,
      :allow_private,
      :skips,
      keyword_init: true
    )

    # defaults
    self.option = Option.new(
      dirs: [],
      requires: [],
      libraries: [],
      timeout: 3,
      size_from: 0,
      size_to: 99,
      size_by: 1,
      skips: [],
      allow_private: false,
    )

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

    attr_accessor :argv, :skip

    def initialize(argv)
      @argv = argv
      @skip = DEFAULT_SKIP
    end

    def load
      OptionParser.new do |o|
        o.on('-I', '--include PATH') do |path|
          CLI.option.dirs << path
        end
        o.on('--library lib', 'load rbs library') do |lib|
          CLI.option.libraries << lib
        end
        o.on('--require lib', 'require ruby library') do |lib|
          CLI.option.requires << lib
        end
        o.on('--log-level level', "default: warn") do |arg|
          RaaP.logger.level = arg
        end
        o.on('--timeout sec', Integer, "default: #{CLI.option.timeout}") do |arg|
          CLI.option.timeout = arg
        end
        o.on('--size-from int', Integer, "default: #{CLI.option.size_from}") do |arg|
          CLI.option.size_from = arg
        end
        o.on('--size-to int', Integer, "default: #{CLI.option.size_to}") do |arg|
          CLI.option.size_to = arg
        end
        o.on('--size-by int', Integer, "default: #{CLI.option.size_by}") do |arg|
          CLI.option.size_by = arg
        end
        o.on('--allow-private', "default: #{CLI.option.allow_private}") do
          CLI.option.allow_private = true
        end
        o.on('--skip tag', "skip case (e.g. `Foo#meth`)") do |tag|
          CLI.option.skips << tag
        end
      end.parse!(@argv)

      CLI.option.dirs.each do |dir|
        RaaP::RBS.loader.add(path: Pathname(dir))
      end
      CLI.option.libraries.each do |lib|
        RaaP::RBS.loader.add(library: lib, version: nil)
      end
      CLI.option.requires.each do |lib|
        require lib
      end
      CLI.option.skips.each do |skip|
        @skip << skip
      end

      self
    end

    def run
      i = 0
      @argv.map do |tag|
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
      end.each do |ret|
        ret.each do |methods|
          methods => { method:, properties: }
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
          end
        end
      end

      self
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
      [
        {
          method:,
          properties: method.method_types.map do |method_type|
            property(receiver_type:, type_params_decl:, type_args:, method_type:, method_name:)
          end
        }
      ]
    end

    def run_by_type_name_with_search(tag:)
      first, _last = tag.split('::')
      ret = []
      RBS.env.class_decls.each do |name, _entry|
        if ['', '::'].any? { |pre| name.to_s.match?(/\A#{pre}#{first}\b/) }
          ret << run_by_type_name(tag: name.to_s)
        end
      end
      ret.flatten(1)
    end

    def run_by_type_name(tag:)
      type = RBS.parse_type(tag)
      type = __skip__ = type
      raise "cannot specified #{type.class}" unless type.respond_to?(:name)

      type_name = type.name.absolute!
      type_args = type.args

      ret = []

      definition = RBS.builder.build_singleton(type_name)
      type_params_decl = definition.type_params_decl
      definition.methods.filter_map do |method_name, method|
        next if @skip.include?("#{type_name.absolute!}.#{method_name}")
        next unless method.accessibility == :public
        next if method.defined_in != type_name

        RaaP.logger.info("# #{type_name}.#{method_name}")
        ret << {
          method:,
          properties: method.method_types.map do |method_type|
            property(receiver_type: Type.new("singleton(#{type.name})"), type_params_decl:, type_args:, method_type:, method_name:)
          end
        }
      end

      definition = RBS.builder.build_instance(type_name)
      type_params_decl = definition.type_params_decl
      definition.methods.filter_map do |method_name, method|
        next if @skip.include?("#{type_name.absolute!}##{method_name}")
        next unless method.accessibility == :public
        next if method.defined_in != type_name

        RaaP.logger.info("# #{type_name}##{method_name}")
        ret << {
          method:,
          properties: method.method_types.map do |method_type|
            property(receiver_type: Type.new(type.name), type_params_decl:, type_args:, method_type:, method_name:)
          end
        }
      end

      ret
    end

    def property(receiver_type:, type_params_decl:, type_args:, method_type:, method_name:)
      rtype = __skip__ = receiver_type.type
      if receiver_type.type.instance_of?(::RBS::Types::ClassSingleton)
        prefix = 'self.'
      else
        prefix = ''
      end
      type_params_decl.each_with_index do |_, i|
        if rtype.instance_of?(::RBS::Types::ClassInstance)
          rtype.args[i] = type_args[i] || ::RBS::Types::Bases::Any.new(location: nil)
        end
      end
      RaaP.logger.info("## def #{prefix}#{method_name}: #{method_type}")
      status = 0
      reason = nil
      stats = MethodProperty.new(
        receiver_type:,
        method_name:,
        method_type: MethodType.new(
          method_type,
          type_params_decl:,
          type_args:,
          self_type: rtype,
          instance_type: ::RBS::Types::ClassInstance.new(name: rtype.name, args: type_args, location: nil),
          class_type: ::RBS::Types::ClassSingleton.new(name: rtype.name, location: nil),
        ),
        size_step: CLI.option.size_from.step(to: CLI.option.size_to, by: CLI.option.size_by),
        timeout: CLI.option.timeout,
        allow_private: true,
      ).run do |called|
        case called
        in Result::Success => s
          print '.'
          RaaP.logger.debug { "Success: #{s.called_str}" }
        in Result::Failure => f
          puts 'F'
          if (e = f.exception)
            RaaP.logger.debug { "Failure: [#{e.class}] #{e.message}" }
            RaaP.logger.debug { e.backtrace.join("\n") }
          end
          RaaP.logger.debug { PP.pp(f.symbolic_call, ''.dup) }
          reason = StringIO.new
          reason.puts "Failed in case of `#{f.called_str}`"
          reason.puts
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
      puts
      stats_log = "success: #{stats.success}, skip: #{stats.skip}, exception: #{stats.exception}"
      RaaP.logger.info(stats_log)

      if status == 0 && stats.success.zero? && !stats.break
        status = 1
        reason = StringIO.new
        reason.puts "Never succeeded => #{stats_log}"
      end

      [status, method_name, method_type, reason]
    end
  end
end
