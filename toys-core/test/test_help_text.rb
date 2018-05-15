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

require "helper"

require "toys/utils/help_text"

describe Toys::Utils::HelpText do
  let(:binary_name) { "toys" }
  let(:tool_name) { ["foo", "bar"] }
  let(:group_tool) do
    Toys::Tool.new(tool_name)
  end
  let(:normal_tool) do
    Toys::Tool.new(tool_name).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_one) do
    Toys::Tool.new(["foo", "bar", "one"])
  end
  let(:subtool_one_a) do
    Toys::Tool.new(["foo", "bar", "one", "a"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_one_b) do
    Toys::Tool.new(["foo", "bar", "one", "b"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_two) do
    Toys::Tool.new(["foo", "bar", "two"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:long_tool_name) { "long-long-long-long-long-long-long-long" }
  let(:subtool_long) do
    Toys::Tool.new(["foo", "bar", long_tool_name])
  end
  let(:empty_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [], [["foo", "bar"], recursive: false])
    m
  end
  let(:group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_two], [["foo", "bar"], recursive: false])
    m
  end
  let(:recursive_group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_one_a, subtool_one_b, subtool_two],
             [["foo", "bar"], recursive: true])
    m
  end
  let(:long_group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_long], [["foo", "bar"], recursive: false])
    m
  end

  describe "short usage" do
    describe "name section" do
      it "renders with no description" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar", help_array[1])
        assert_equal("", help_array[2])
      end

      it "renders with a description" do
        normal_tool.desc = "Hello world"
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar - Hello world", help_array[1])
        assert_equal("", help_array[2])
      end

      it "renders with wrapping" do
        normal_tool.desc = Toys::Utils::WrappableString.new("Hello world")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 25).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar - Hello", help_array[1])
        assert_equal("        world", help_array[2])
        assert_equal("", help_array[3])
      end

      it "does not break the tool name when wrapping" do
        normal_tool.desc = Toys::Utils::WrappableString.new("Hello world")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 5).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar -", help_array[1])
        assert_equal("        Hello", help_array[2])
        assert_equal("        world", help_array[3])
        assert_equal("", help_array[4])
      end
    end

    describe "synopsis section" do
      it "is set for a group" do
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar TOOL [ARGUMENTS...]", help_array[index + 1])
        assert_equal("    toys foo bar", help_array[index + 2])
        assert_equal("", help_array[index + 3])
      end

      it "is set for a group with an executor" do
        help = Toys::Utils::HelpText.new(normal_tool, group_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar", help_array[index + 1])
        assert_equal("    toys foo bar TOOL [ARGUMENTS...]", help_array[index + 2])
        assert_equal("", help_array[index + 3])
      end

      it "is set for a normal tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar", help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "is set for a normal tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [-a VALUE, --aa=VALUE] [--[no-]bb]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with required args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar CC DD", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with optional args" do
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [EE] [FF]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with remaining args" do
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [GG...]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with the kitchen sink and wrapping" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 40).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [-a VALUE, --aa=VALUE]", help_array[index + 1])
        assert_equal("        [--[no-]bb] CC DD [EE] [FF]", help_array[index + 2])
        assert_equal("        [GG...]", help_array[index + 3])
        assert_equal("", help_array[index + 4])
      end
    end

    describe "flags section" do
      it "is not present for a tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        assert_nil(index)
      end

      it "is set for a tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -a VALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        set aa", help_array[index + 2])
        assert_equal("", help_array[index + 3])
        assert_equal("    --[no-]bb", help_array[index + 4])
        assert_equal("        set bb", help_array[index + 5])
        assert_equal(index + 6, help_array.size)
      end

      it "orders single dashes before double dashes" do
        normal_tool.add_flag(:aa, ["--aa=VALUE", "-a"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -a VALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        set aa", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "handles no description" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"])
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -a VALUE, --aa=VALUE", help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "prefers long description over short description" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "short desc", long_desc: "long desc")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -a VALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "wraps long description" do
        long_desc = ["long desc", Toys::Utils::WrappableString.new("hello ruby world")]
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], long_desc: long_desc)
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -a VALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal("        hello ruby", help_array[index + 3])
        assert_equal("        world", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end
    end

    describe "positional args section" do
      it "is not present for a tool with no args" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        assert_nil(index)
      end

      it "is set for a tool with args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        set cc", help_array[index + 2])
        assert_equal("", help_array[index + 3])
        assert_equal("    DD", help_array[index + 4])
        assert_equal("        set dd", help_array[index + 5])
        assert_equal("", help_array[index + 6])
        assert_equal("    [EE]", help_array[index + 7])
        assert_equal("        set ee", help_array[index + 8])
        assert_equal("", help_array[index + 9])
        assert_equal("    [FF]", help_array[index + 10])
        assert_equal("        set ff", help_array[index + 11])
        assert_equal("", help_array[index + 12])
        assert_equal("    [GG...]", help_array[index + 13])
        assert_equal("        set gg", help_array[index + 14])
        assert_equal(index + 15, help_array.size)
      end

      it "handles no description" do
        normal_tool.add_required_arg(:cc)
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff)
        normal_tool.set_remaining_args(:gg)
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("", help_array[index + 2])
        assert_equal("    DD", help_array[index + 3])
        assert_equal("        set dd", help_array[index + 4])
        assert_equal("", help_array[index + 5])
        assert_equal("    [EE]", help_array[index + 6])
        assert_equal("        set ee", help_array[index + 7])
        assert_equal("", help_array[index + 8])
        assert_equal("    [FF]", help_array[index + 9])
        assert_equal("", help_array[index + 10])
        assert_equal("    [GG...]", help_array[index + 11])
        assert_equal(index + 12, help_array.size)
      end

      it "prefers long description over short description" do
        normal_tool.add_required_arg(:cc, desc: "short desc", long_desc: "long desc")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "wraps long description" do
        long_desc = ["long desc", Toys::Utils::WrappableString.new("hello ruby world")]
        normal_tool.add_required_arg(:cc, long_desc: long_desc)
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal("        hello ruby", help_array[index + 3])
        assert_equal("        world", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end
    end

    describe "subtools section" do
      it "is not present for a normal tool" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("TOOLS")
        assert_nil(index)
      end

      it "is set for a group non-recursive" do
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one", help_array[index + 1])
        assert_equal("    two", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "is set for a group recursive" do
        help = Toys::Utils::HelpText.new(group_tool, recursive_group_loader, binary_name)
        help_array = help.help_string(styled: false, recursive: true).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one", help_array[index + 1])
        assert_equal("    one a", help_array[index + 2])
        assert_equal("    one b", help_array[index + 3])
        assert_equal("    two", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end

      it "shows subtool desc" do
        subtool_one.desc = "one desc"
        subtool_one.long_desc = ["long desc"]
        subtool_two.desc = Toys::Utils::WrappableString.new("two desc on two lines")
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one - one desc", help_array[index + 1])
        assert_equal("    two - two desc", help_array[index + 2])
        assert_equal("        on two lines", help_array[index + 3])
        assert_equal(index + 4, help_array.size)
      end
    end
  end

  describe "usage string" do
    describe "synopsis" do
      it "is set for a group" do
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar TOOL [ARGUMENTS...]", usage_array[0])
        assert_equal("        toys foo bar", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a group with an executor" do
        help = Toys::Utils::HelpText.new(normal_tool, group_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar", usage_array[0])
        assert_equal("        toys foo bar TOOL [ARGUMENTS...]", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a normal tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar", usage_array[0])
        assert_equal(1, usage_array.size)
      end

      it "is set for a normal tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with required args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar CC DD", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with optional args" do
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [EE] [FF]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with remaining args" do
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [GG...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with the kitchen sink" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...] CC DD [EE] [FF] [GG...]",
                     usage_array[0])
        assert_equal("", usage_array[1])
      end
    end

    describe "subtools section" do
      it "is not present for a normal tool" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Tools:")
        assert_nil(index)
      end

      it "is set for a group non-recursive" do
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "is set for a group recursive" do
        help = Toys::Utils::HelpText.new(group_tool, recursive_group_loader, binary_name)
        usage_array = help.usage_string(recursive: true).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}one a\s{28}$/, usage_array[index + 2])
        assert_match(/^\s{4}one b\s{28}$/, usage_array[index + 3])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 4])
        assert_equal(index + 5, usage_array.size)
      end

      it "shows subtool desc" do
        subtool_one.desc = "one desc"
        subtool_two.desc = Toys::Utils::WrappableString.new("two desc on two lines")
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = help.usage_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}one desc$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}two desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end

      it "shows desc for long subtool name" do
        subtool_long.desc = Toys::Utils::WrappableString.new("long desc on two lines")
        help = Toys::Utils::HelpText.new(group_tool, long_group_loader, binary_name)
        usage_array = help.usage_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}#{long_tool_name}$/, usage_array[index + 1])
        assert_match(/^\s{37}long desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end
    end

    describe "positional args section" do
      it "is not present for a group" do
        help = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is not present for a normal tool with no positional args" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is set for a normal tool with positional args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        refute_nil(index)
        assert_match(/^\s{4}CC\s{31}set cc$/, usage_array[index + 1])
        assert_match(/^\s{4}DD\s{31}set dd$/, usage_array[index + 2])
        assert_match(/^\s{4}\[EE\]\s{29}set ee$/, usage_array[index + 3])
        assert_match(/^\s{4}\[FF\]\s{29}set ff$/, usage_array[index + 4])
        assert_match(/^\s{4}\[GG\.\.\.\]\s{26}set gg$/, usage_array[index + 5])
        assert_equal(index + 6, usage_array.size)
      end

      it "shows desc for long arg" do
        normal_tool.add_required_arg(:long_long_long_long_long_long_long_long,
                                     desc: Toys::Utils::WrappableString.new("set long arg desc"))
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string(wrap_width: 47).split("\n")
        index = usage_array.index("Positional arguments:")
        refute_nil(index)
        assert_match(/^\s{4}LONG_LONG_LONG_LONG_LONG_LONG_LONG_LONG$/, usage_array[index + 1])
        assert_match(/^\s{37}set long$/, usage_array[index + 2])
        assert_match(/^\s{37}arg desc$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end
    end

    describe "flags section" do
      it "is not present for a tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        assert_nil(index)
      end

      it "is set for a tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa=VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_match(/^\s{8}--\[no-\]bb\s{20}set bb$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "shows value only for last flag" do
        normal_tool.add_flag(:aa, ["-a VALUE", "--aa"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end

      it "orders single dashes before double dashes" do
        normal_tool.add_flag(:aa, ["--aa", "-a VALUE"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end
    end
  end
end
