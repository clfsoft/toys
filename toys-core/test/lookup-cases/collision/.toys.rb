# frozen_string_literal: true

tool "tool-1" do
  desc "index tool-1 short description"
  long_desc "index tool-1 long description"

  def run
    puts "index tool-1 execution"
  end
end

tool "tool-2" do
  desc "index tool-2 short description"
  long_desc "index tool-2 long description"

  def run
    puts "index tool-2 execution"
  end
end