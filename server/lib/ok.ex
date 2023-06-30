defmodule OK do
  alias ExUnit.AssertionError
  def ok({:ok, _} = x), do: x
  def ok({:error, _} = x), do: x
  def ok(x), do: {:ok, x}

  def error({:ok, _} = x), do: x
  def error({:error, _} = x), do: x
  def error(x), do: {:error, x}

  def unwrap_ok!({:ok, x}), do: x

  def unwrap_ok!({:error, _} = x),
    do:
      raise("""
      unwrap_ok! called on error tuple:
          #{inspect(x, pretty: true)}
      """)

  def unwrap_ok!(x),
    do:
      raise("""
      unwrap_ok! called on non-tuple:
          #{inspect(x, pretty: true)}
      """)

  def unwrap_error!({:error, x}), do: x

  def unwrap_error!({:ok, _} = x),
    do:
      raise("""
      unwrap_error! called on ok tuple:
          #{inspect(x, pretty: true)}
      """)

  def unwrap_error!(x),
    do:
      raise("""
      unwrap_error! called on non-tuple:
          #{inspect(x, pretty: true)}
      """)

  defmacro assert!(do: block) do
    quote do
      try do
        unless unquote(block) do
          raise AssertionError, """
          Assertion failed:

              #{inspect(unquote(block), pretty: true)}

          Reason:

              Block returned non-truthy value.
          """
        end
      rescue
        e ->
          raise AssertionError, """
          Assertion failed:

              #{inspect(unquote(block), pretty: true)}

          Reason
              #{inspect(e, pretty: true)}
          """
      end
    end
  end
end
