defmodule StreamComprehensionTest do
  use ExUnit.Case
  doctest StreamComprehension

  test "greets the world" do
    assert StreamComprehension.hello() == :world
  end
end
