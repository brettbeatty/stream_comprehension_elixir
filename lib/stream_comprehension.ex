defmodule StreamComprehension do
  @moduledoc """
  StreamComprehension allows for comprehensions to build streams instead of lists.

  Stream comprehensions do not support the `:into` or `:reduce` options because the output would
  then not be a stream, and regular comprehensions suffice.
  """
  @typep reason() ::
           :invalid_opt
           | :invalid_opts
           | :invalid_uniq
           | :missing_do
           | :start_with_generator
           | {:usage, arity :: 1..2}
  @typep acc() :: %{ast: Macro.t(), env: Macro.Env.t(), uniq: boolean()}

  @doc """
  Build a stream from the given for comprehension instead of a list.

  For more information about comprehensions, see `Kernel.SpecialForms.for/1`.

  For more information about streams, see `Stream`.

  Stream comprehensions do not support the `:into` or `:reduce` options because the output would
  then not be a stream, and regular comprehensions would do the same thing. The `:uniq` option
  is still supported.

  ## Examples

      iex> import StreamComprehension
      iex> input = Stream.cycle([ok: "twenty-three", error: "forty-two", ok: "nineteen"])
      iex> my_stream =
      ...>   stream for {:ok, word} <- input,
      ...>              <<character <- word>>,
      ...>              character in ?a..?z do
      ...>     character
      ...>   end
      iex> Enum.take(my_stream, 38)
      'twentythreenineteentwentythreenineteen'

  """
  defmacro stream(comprehension)

  defmacro stream({:for, _meta, args}) when is_list(args) do
    if starts_with_generator?(args) do
      args
      |> Enum.reverse()
      |> build_stream(__CALLER__)
    else
      raise compile_error(:start_with_generator, __CALLER__)
    end
  end

  defmacro stream(_comprehension) do
    raise compile_error({:usage, _arity = 1}, __CALLER__)
  end

  @doc """
  Same as `stream/1`.

  Depending how your :do blocks and optional parentheses work out, the :do block can be passed to
  `stream/2` instead of `for/1`, so `stream/2` exists to handle those cases.
  """
  defmacro stream(comprehension, block)

  defmacro stream({:for, _meta, args}, opts) when is_list(args) and is_list(opts) do
    if starts_with_generator?(args) do
      build_stream([opts | Enum.reverse(args)], __CALLER__)
    else
      raise compile_error(:start_with_generator, __CALLER__)
    end
  end

  defmacro stream(_comprehension, _block) do
    raise compile_error({:usage, _arity = 2}, __CALLER__)
  end

  @spec starts_with_generator?([Macro.t()]) :: boolean()
  defp starts_with_generator?(args)

  defp starts_with_generator?([{:<<>>, _meta, parts} | _args]) do
    case bitstring_generator(parts) do
      {_match, _bitstring} ->
        true

      :error ->
        false
    end
  end

  defp starts_with_generator?([{:<-, _meta, [_match, _enumerable]} | _args]) do
    true
  end

  defp starts_with_generator?(_args) do
    false
  end

  @spec build_stream([Macro.t()], Macro.Env.t()) :: Macro.t()
  defp build_stream(args, env) do
    with [opts | remaining] when is_list(opts) <- args,
         {[do: block], new_opts} <- Keyword.split(opts, [:do]) do
      build_stream([new_opts | remaining], block, env)
    else
      _ ->
        raise compile_error(:missing_do, env)
    end
  end

  @spec build_stream([Macro.t()], Macro.t(), Macro.Env.t()) :: Macro.t()
  defp build_stream(args, block, env) do
    acc = %{ast: [block], env: env, uniq: false}

    %{ast: ast, uniq: uniq} = Enum.reduce(args, acc, &apply_arg/2)

    if uniq do
      quote do
        Stream.uniq(unquote(ast))
      end
    else
      ast
    end
  end

  @spec apply_arg(Macro.t(), acc()) :: acc()
  defp apply_arg(arg, acc)

  defp apply_arg({:<-, _meta, [match, enumerable]}, acc) do
    ast =
      quote generated: true do
        Stream.flat_map(unquote(enumerable), fn
          unquote(match) -> unquote(acc.ast)
          _ -> []
        end)
      end

    %{acc | ast: ast}
  end

  defp apply_arg({:<<>>, _meta, parts}, acc) do
    case bitstring_generator(parts) do
      {match, bitstring} ->
        ast =
          quote do
            Stream.resource(
              fn -> unquote(bitstring) end,
              fn
                <<unquote_splicing(match), remaining::bitstring>> ->
                  {unquote(acc.ast), remaining}

                bitstring ->
                  {:halt, bitstring}
              end,
              fn _bitstring -> [] end
            )
          end

        %{acc | ast: ast}

      :error ->
        acc
    end
  end

  defp apply_arg(opts, acc) when is_list(opts) do
    Enum.reduce(opts, acc, &apply_opt/2)
  end

  defp apply_arg(condition, acc) do
    ast =
      quote do
        if unquote(condition) do
          unquote(acc.ast)
        else
          []
        end
      end

    %{acc | ast: ast}
  end

  @spec bitstring_generator([Macro.t()]) ::
          {parts :: [Macro.t()], bitstring :: Macro.t()} | :error
  defp bitstring_generator(parts) do
    case Enum.reverse(parts) do
      [{:<-, _meta, [part, bitstring]} | remaining] ->
        {Enum.reverse([part | remaining]), bitstring}

      _reversed ->
        :error
    end
  end

  @spec apply_opt({:uniq, boolean()} | term(), acc()) :: acc() | no_return()
  defp apply_opt(opt, acc)

  defp apply_opt({:uniq, uniq}, acc) do
    if is_boolean(uniq) do
      %{acc | uniq: uniq}
    else
      raise compile_error({:invalid_uniq, uniq}, acc.env)
    end
  end

  defp apply_opt({opt, _value}, acc) do
    raise compile_error({:invalid_opt, opt}, acc.env)
  end

  defp apply_opt(_opt, acc) do
    raise compile_error(:invalid_opts, acc.env)
  end

  @spec compile_error(reason(), Macro.Env.t()) :: Exception.t()
  defp compile_error(reason, env) do
    CompileError.exception(description: describe(reason), file: env.file, line: env.line)
  end

  @spec describe(reason()) :: String.t()
  defp describe(reason)

  defp describe({:invalid_opt, opt}) do
    "unsupported option #{inspect(opt)} given to for"
  end

  defp describe(:invalid_opts) do
    "for comprehension options must be in keyword list"
  end

  defp describe({:invalid_uniq, uniq}) do
    ":uniq option for comprehensions only accepts a boolean, got: #{inspect(uniq)}"
  end

  defp describe(:missing_do) do
    ~S(missing :do option in "for")
  end

  defp describe(:start_with_generator) do
    "for comprehensions must start with a generator"
  end

  defp describe({:usage, arity}) do
    "StreamComprehension.stream/#{arity} can only be passed a for comprehension"
  end
end
