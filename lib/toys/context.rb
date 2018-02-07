module Toys
  class Context
    def initialize(lookup, logger: nil, binary_name: nil, tool_name: nil, args: nil, options: nil)
      @_lookup = lookup
      @logger = logger || Logger.new(STDERR)
      @binary_name = binary_name
      @tool_name = tool_name
      @args = args
      @options = options
    end

    attr_reader :logger
    attr_reader :binary_name
    attr_reader :tool_name
    attr_reader :args
    attr_reader :options

    def [](key)
      @options[key]
    end

    def run(*args)
      args = args.flatten
      tool = @_lookup.lookup(args)
      tool.execute(self, args.slice(tool.full_name.length..-1))
    end

    attr_reader :_lookup

    def _create_child(tool_name, args, options)
      Context.new(@_lookup, logger: @logger, binary_name: @binary_name,
        tool_name: tool_name, args: args, options: options)
    end
  end
end
