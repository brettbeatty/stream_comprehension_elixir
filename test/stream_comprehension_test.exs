defmodule StreamComprehensionTest do
  use ExUnit.Case, async: true
  doctest StreamComprehension

  defmacrop assert_compile_error(message, do: block) do
    quote bind_quoted: [message: message, block: Macro.escape(block)] do
      new_block =
        quote do
          import StreamComprehension

          unquote(block)
        end

      exception = assert_raise CompileError, fn -> Code.eval_quoted(new_block) end
      assert Exception.message(exception) =~ message
    end
  end

  describe "stream/1" do
    import StreamComprehension, only: [stream: 1]

    test "success: returns an enumerable" do
      my_stream = stream for x <- ?a..?c, do: x

      assert Enum.to_list(my_stream) == 'abc'
    end

    test "success: supports map operations" do
      my_stream = stream for x <- ?a..?c, do: x + 1

      assert Enum.to_list(my_stream) == 'bcd'
    end

    test "success: supports filter operations" do
      my_stream = stream for x <- ?a..?c, x != ?b, do: x

      assert Enum.to_list(my_stream) == 'ac'
    end

    test "success: supports match filtering" do
      my_stream = stream for {:ok, x} <- [ok: ?a, error: ?b, ok: ?c], do: x

      assert Enum.to_list(my_stream) == 'ac'
    end

    test "success: supports bitstring generators" do
      input = <<1, 2, 3, 4>>
      assert input == <<1, 0::4, 32, 3::4, 4>>

      my_stream = stream for <<a, b::4 <- input>>, do: {a, b}

      assert Enum.to_list(my_stream) == [{1, 0}, {32, 3}]
    end

    test "success: not :uniq by default" do
      my_stream = stream for x <- 'aabc', do: x + 1

      assert Enum.to_list(my_stream) == 'bbcd'
    end

    test "success: supports :uniq option" do
      my_stream = stream for x <- 'aabc', uniq: true, do: x + 1

      assert Enum.to_list(my_stream) == 'bcd'
    end

    test "success: supports multiple generators" do
      my_stream = stream for x <- ?a..?c, x != ?b, <<y <- "def">>, do: <<x, y>>

      assert Enum.to_list(my_stream) == ["ad", "ae", "af", "cd", "ce", "cf"]
    end

    test "success: does not evaluate skipped expressions" do
      my_stream = stream for {:ok, x} <- [ok: ?a, error: ?b, ok: ?c], x != ?c, do: send(self(), x)

      Stream.run(my_stream)

      assert_received ?a
      refute_received ?b
      refute_received ?c
    end

    test "success: operations performed lazily" do
      my_stream =
        stream for x <- ?a..?c, x != ?b, y <- ?d..?f, y == ?f, do: send(self(), <<x, y>>)

      refute_received "af"
      refute_received "cf"

      Stream.run(my_stream)

      assert_received "af"
      assert_received "cf"
    end

    test "error: fails if not passed a for comprehension" do
      assert_compile_error "StreamComprehension.stream/1 can only be passed a for comprehension" do
        stream x
      end
    end

    test "error: fails if comprehension does not start with generator" do
      assert_compile_error "for comprehensions must start with a generator" do
        stream for x, do: x
      end
    end

    test "error: fails if no :do block" do
      assert_compile_error ~S(missing :do option in "for") do
        stream for x <- 1..3
      end
    end

    test "error: fails if :uniq option not boolean" do
      assert_compile_error ":uniq option for comprehensions only accepts a boolean, got: :yes" do
        stream for x <- 1..3, uniq: :yes, do: x
      end
    end

    test "error: fails if unsupported option passed" do
      assert_compile_error "unsupported option :into given to for" do
        stream for x <- 1..3, into: MapSet.new(), do: x
      end
    end

    test "error: fails if options not in keyword list" do
      assert_compile_error "for comprehension options must be in keyword list" do
        stream for x <- 1..3, [:uniq], do: x
      end
    end
  end

  describe "stream/2" do
    import StreamComprehension, only: [stream: 2]

    test "success: returns an enumerable" do
      my_stream =
        stream for x <- ?a..?c do
          x
        end

      assert Enum.to_list(my_stream) == 'abc'
    end

    test "success: supports map operations" do
      my_stream =
        stream for x <- ?a..?c do
          x + 1
        end

      assert Enum.to_list(my_stream) == 'bcd'
    end

    test "success: supports filter operations" do
      my_stream =
        stream for x <- ?a..?c, x != ?b do
          x
        end

      assert Enum.to_list(my_stream) == 'ac'
    end

    test "success: supports match filtering" do
      my_stream =
        stream for {:ok, x} <- [ok: ?a, error: ?b, ok: ?c] do
          x
        end

      assert Enum.to_list(my_stream) == 'ac'
    end

    test "success: supports bitstring generators" do
      input = <<1, 2, 3, 4>>
      assert input == <<1, 0::4, 32, 3::4, 4>>

      my_stream =
        stream for <<a, b::4 <- input>> do
          {a, b}
        end

      assert Enum.to_list(my_stream) == [{1, 0}, {32, 3}]
    end

    test "success: not :uniq by default" do
      my_stream =
        stream for x <- 'aabc' do
          x + 1
        end

      assert Enum.to_list(my_stream) == 'bbcd'
    end

    test "success: supports :uniq option" do
      my_stream =
        stream for x <- 'aabc', uniq: true do
          x + 1
        end

      assert Enum.to_list(my_stream) == 'bcd'
    end

    test "success: supports multiple generators" do
      my_stream =
        stream for x <- ?a..?c, x != ?b, <<y <- "def">> do
          <<x, y>>
        end

      assert Enum.to_list(my_stream) == ["ad", "ae", "af", "cd", "ce", "cf"]
    end

    test "success: does not evaluate skipped expressions" do
      my_stream =
        stream for {:ok, x} <- [ok: ?a, error: ?b, ok: ?c], x != ?c do
          send(self(), x)
        end

      Stream.run(my_stream)

      assert_received ?a
      refute_received ?b
      refute_received ?c
    end

    test "success: operations performed lazily" do
      my_stream =
        stream for x <- ?a..?c, x != ?b, y <- ?d..?f, y == ?f do
          send(self(), <<x, y>>)
        end

      refute_received "af"
      refute_received "cf"

      Stream.run(my_stream)

      assert_received "af"
      assert_received "cf"
    end

    test "error: fails if not passed a for comprehension" do
      assert_compile_error "StreamComprehension.stream/2 can only be passed a for comprehension" do
        stream x do
          x
        end
      end
    end

    test "error: fails if comprehension does not start with generator" do
      assert_compile_error "for comprehensions must start with a generator" do
        stream for x do
          x
        end
      end
    end

    test "error: fails if no :do block" do
      assert_compile_error ~S(missing :do option in "for") do
        stream(for(x <- 1..3), [])
      end
    end

    test "error: fails if :uniq option not boolean" do
      assert_compile_error ":uniq option for comprehensions only accepts a boolean, got: :yes" do
        stream for x <- 1..3, uniq: :yes do
          x
        end
      end
    end

    test "error: fails if unsupported option passed" do
      assert_compile_error "unsupported option :into given to for" do
        stream for x <- 1..3, into: MapSet.new() do
          x
        end
      end
    end

    test "error: fails if options not in keyword list" do
      assert_compile_error "for comprehension options must be in keyword list" do
        stream for x <- 1..3, [:uniq] do
          x
        end
      end
    end
  end
end
