defmodule StreamComprehensionTest do
  use ExUnit.Case, async: true

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
    test "error: fails if not passed a for comprehension" do
      assert_compile_error "StreamComprehension.stream/1 can only be passed a for comprehension" do
        stream []
      end
    end

    test "error: fails if comprehension does not start with generator" do
      assert_compile_error "for comprehensions must start with a generator" do
        stream for 1..3, do: []
      end
    end
  end

  describe "stream/2" do
    test "error: fails if not passed a for comprehension" do
      assert_compile_error "StreamComprehension.stream/2 can only be passed a for comprehension" do
        stream 1..3 do
          []
        end
      end
    end

    test "error: fails if comprehension does not start with generator" do
      assert_compile_error "for comprehensions must start with a generator" do
        stream for 1..3 do
          []
        end
      end
    end
  end
end
