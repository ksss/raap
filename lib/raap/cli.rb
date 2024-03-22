# frozen_string_literal: true

module RaaP
  # $ raap Integer#pow
  # $ raap -I sig RaaP::Type
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
    )

    def initialize(argv)
      @argv = argv
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

      self
    end

    def run
      @argv.map do |tag|
        case
        when tag.include?('#')
          run_by_instance(tag:)
        when tag.include?('.')
          run_by_singleton(tag:)
        when tag.end_with?('*')
          run_by_type_name_with_search(tag:)
        else
          run_by_type_name(tag:)
        end
      end.each do |ret|
        ret.each do |methods|
          methods.each do |status, method_name, method_type|
            if status == 1
              puts "Fail:"
              puts "def #{method_name}: #{method_type}"
            end
          end
        end
      end

      self
    end

    def run_by_instance(tag:)
      t, m = tag.split('#', 2)
      t or raise
      m or raise
      type = RBS.parse_type(t)
      type = __skip__ = type
      raise "cannot specified #{type}" unless type.respond_to?(:name)
      receiver_type = Type.new(type.to_s)
      method_name = m.to_sym
      definition = RBS.builder.build_instance(type.name)
      type_params_decl = definition.type_params_decl
      method = definition.methods[method_name]
      raise "`#{tag}` is not found" unless method
      puts "# #{type.to_s}"
      puts
      [
        method.method_types.map do |method_type|
          property(receiver_type:, type_params_decl:, method_type:, method_name:)
        end
      ]
    end

    def run_by_singleton(tag:)
      t, m = tag.split('.', 2)
      t or raise
      m or raise
      type = RBS.parse_type(t)
      raise "cannot specified #{type.class}" unless type.respond_to?(:name)
      type = __skip__ = type
      receiver_type = Type.new("singleton(#{type.name})")
      method_name = m.to_sym
      definition = RBS.builder.build_singleton(type.name)
      method = definition.methods[method_name]
      type_params_decl = definition.type_params_decl
      raise "`#{tag}` not found" unless method
      puts "# #{type}"
      puts
      [
        method.method_types.map do |method_type|
          property(receiver_type:, type_params_decl:, method_type:, method_name:)
        end
      ]
    end

    def run_by_type_name_with_search(tag:)
      first, _last = tag.split('::')
      ret = []
      RBS.env.class_decls.each do |name, entry|
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

      ret = []

      definition = RBS.builder.build_singleton(type_name)
      type_params_decl = definition.type_params_decl
      definition.methods.filter_map do |method_name, method|
        next unless method.accessibility == :public
        next if method.defined_in != type_name
        next if method_name == :fork || method_name == :spawn # TODO: skip solution
        puts "# #{type_name}.#{method_name}"
        puts
        ret << method.method_types.map do |method_type|
          property(receiver_type: Type.new("singleton(#{type})"), type_params_decl:, method_type:, method_name:)
        end
      end

      definition = RBS.builder.build_instance(type_name)
      type_params_decl = definition.type_params_decl
      definition.methods.filter_map do |method_name, method|
        next unless method.accessibility == :public
        next if method.defined_in != type_name
        next if method_name == :fork || method_name == :spawn # TODO: skip solution
        puts "# #{type_name}##{method_name}"
        puts
        ret << method.method_types.map do |method_type|
          property(receiver_type: Type.new(type.to_s), type_params_decl:, method_type:, method_name:)
        end
      end

      ret
    end

    def property(receiver_type:, type_params_decl:, method_type:, method_name:)
      rtype = __skip__ = receiver_type.type
      if receiver_type.type.instance_of?(::RBS::Types::ClassSingleton)
        prefix = 'self.'
        type_args = []
      else
        prefix = ''
        type_args = rtype.args
      end
      puts "## def #{prefix}#{method_name}: #{method_type}"
      status = 0
      stats = MethodProperty.new(
        receiver_type:,
        method_name: method_name,
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
      ).run do |called|
        case called
        in Result::Success => s
          print '.'
          RaaP.logger.debug { "Success: #{s.called_str}" }
        in Result::Failure => f
          puts 'F'
          puts "Failed in case of `#{f.called_str}`"
          puts
          RaaP.logger.debug { PP.pp(f.symbolic_call, ''.dup) }
          puts "### call stack:"
          puts
          puts "```"
          puts SymbolicCaller.new(f.symbolic_call).to_lines.join("\n")
          puts "```"
          status = 1
          throw :break
        in Result::Skip => s
          print 'S'
          RaaP::logger.debug("Skip: [#{s.exception.class}] #{s.exception.message}")
        in Result::Exception => e
          print 'E'
          RaaP.logger.info("#{e.exception.class}: #{e.exception.message}")
          RaaP.logger.debug(e.exception.backtrace.join("\n"))
        end
      end
      puts
      puts "success: #{stats.success}, skip: #{stats.skip}, exception: #{stats.exception}"
      puts

      [status, method_name, method_type]
    end
  end
end
