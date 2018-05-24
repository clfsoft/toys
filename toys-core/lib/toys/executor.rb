# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "optparse"

module Toys
  ##
  # An internal class that manages execution of a tool
  # @private
  #
  class Executor
    def initialize(cli, tool_definition)
      @cli = cli
      @tool_definition = tool_definition
    end

    def execute(args, verbosity: 0)
      data = create_data(args, verbosity)
      parse_args(args, data)
      tool = @tool_definition.tool_class.new(@cli, data)

      original_level = @cli.logger.level
      @cli.logger.level = @cli.base_level - data[Tool::VERBOSITY]
      begin
        perform_execution(tool)
      ensure
        @cli.logger.level = original_level
      end
    end

    private

    def create_data(args, base_verbosity)
      data = @tool_definition.default_data.dup
      data[Tool::TOOL_DEFINITION] = @tool_definition
      data[Tool::TOOL_NAME] = @tool_definition.full_name
      data[Tool::VERBOSITY] = base_verbosity
      data[Tool::ARGS] = args
      data[Tool::USAGE_ERROR] = nil
      data
    end

    def parse_args(args, data)
      optparse = create_option_parser(data)
      remaining = optparse.parse(args)
      remaining = parse_required_args(remaining, args, data)
      remaining = parse_optional_args(remaining, data)
      parse_remaining_args(remaining, args, data)
    rescue ::OptionParser::ParseError => e
      data[Tool::USAGE_ERROR] = e.message
    end

    def create_option_parser(data)
      optparse = ::OptionParser.new
      # The following clears out the Officious (hidden default flags).
      optparse.remove
      optparse.remove
      optparse.new
      optparse.new
      @tool_definition.flag_definitions.each do |flag|
        optparse.on(*flag.optparser_info) do |val|
          data[flag.key] = flag.handler.call(val, data[flag.key])
        end
      end
      @tool_definition.custom_acceptors do |accept|
        optparse.accept(accept)
      end
      optparse
    end

    def parse_required_args(remaining, args, data)
      @tool_definition.required_arg_definitions.each do |arg_info|
        if remaining.empty?
          reason = "No value given for required argument #{arg_info.display_name}"
          raise create_parse_error(args, reason)
        end
        data[arg_info.key] = arg_info.process_value(remaining.shift)
      end
      remaining
    end

    def parse_optional_args(remaining, data)
      @tool_definition.optional_arg_definitions.each do |arg_info|
        break if remaining.empty?
        data[arg_info.key] = arg_info.process_value(remaining.shift)
      end
      remaining
    end

    def parse_remaining_args(remaining, args, data)
      return if remaining.empty?
      unless @tool_definition.remaining_args_definition
        if @tool_definition.includes_script?
          raise create_parse_error(remaining, "Extra arguments provided")
        else
          raise create_parse_error(@tool_definition.full_name + args, "Tool not found")
        end
      end
      data[@tool_definition.remaining_args_definition.key] =
        remaining.map { |arg| @tool_definition.remaining_args_definition.process_value(arg) }
    end

    def create_parse_error(path, reason)
      OptionParser::ParseError.new(*path).tap do |e|
        e.reason = reason
      end
    end

    def perform_execution(tool)
      executor = proc do
        if @tool_definition.includes_script?
          tool.instance_eval(&@tool_definition.script)
        else
          @cli.logger.fatal("No implementation for tool #{@tool_definition.display_name.inspect}")
          tool.exit(-1)
        end
      end
      @tool_definition.middleware_stack.reverse.each do |middleware|
        executor = make_executor(middleware, tool, executor)
      end
      catch(:result) do
        executor.call
        0
      end
    end

    def make_executor(middleware, tool, next_executor)
      proc { middleware.execute(tool, &next_executor) }
    end
  end
end