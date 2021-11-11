defmodule StreamComprehension do
  @typep reason() :: :start_with_generator | {:usage, arity :: 1..2}
  @typep state() :: %{ast: Macro.t(), uniq: boolean()}

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

  @spec build_stream([Macro.t()], Macro.Env.t()) :: Macro.t()
  defp build_stream(_args, _env) do
    raise "not implemented"
  end

  @spec starts_with_generator?([Macro.t()]) :: boolean()
  defp starts_with_generator?(args) do
    match?([{:<-, _meta, [_match, _enumerable]} | _args], args)
  end

  @spec compile_error(reason(), Macro.Env.t()) :: Exception.t()
  defp compile_error(reason, env) do
    CompileError.exception(description: describe(reason), file: env.file, line: env.line)
  end

  @spec describe(reason()) :: String.t()
  defp describe(reason)

  defp describe(:start_with_generator) do
    "for comprehensions must start with a generator"
  end

  defp describe({:usage, arity}) do
    "StreamComprehension.stream/#{arity} can only be passed a for comprehension"
  end
end
