defmodule Server.Plugin.Pointer do
  @moduledoc """
  An implementation of RFC 6901.
  """

  @type json() :: map() | list() | number() | String.t() | boolean() | nil
  @type resolve_error() ::
          :not_found
          | :index_out_of_bounds
          | :append_not_allowed
          | :invalid_array_index
          | :invalid_object

  @doc """
  Quoth the docs:

  > Evaluation of a JSON Pointer begins with a reference to the root
  > value of a JSON document and completes with a reference to some value
  > within the document.  Each reference token in the JSON Pointer is
  > evaluated sequentially.
  >
  > Evaluation of each reference token begins by decoding any escaped
  > character sequence.  This is performed by first transforming any
  > occurrence of the sequence `~1` to `/`, and then transforming any
  > occurrence of the sequence `~0` to `~`.  By performing the
  > substitutions in this order, an implementation avoids the error of
  > turning `~01` first into `~1` and then into `/`, which would be
  > incorrect (the string `~01` correctly becomes `~1` after
  > transformation).

  - If the value being resolved is an object, find the next value by property
    name.

  - If the value being resolved is an array, the next value is either the
    number that is the current value, or the string "`-`" to indicate the
    nonexistent member *after* the last array element.

  This function accepts the following options:

  - `:allow_array_append`: Allows using the `-` reference to the nonexistent
    member after the last array element. Defaults to `false`.
  """
  @spec resolve(
          object :: json(),
          pointer :: String.t(),
          options :: Keyword.t()
        ) ::
          {:ok, [String.t()]}
          | {:error, {pointer :: String.t(), token :: String.t(), reason :: atom()}}
  def resolve(object, "/" <> pointer, options \\ []) do
    allow_array_append = Keyword.get(options, :allow_array_append, false)

    case String.split(pointer, "/", parts: 2) do
      [token] ->
        object
        |> resolve_token(token, allow_array_append)
        |> format_token_error(pointer)

      [token, rest] ->
        case resolve_token(object, token, allow_array_append) do
          {:ok, next_object} ->
            resolve(next_object, "/" <> rest, options)

          {:error, reason} ->
            {:error, {token, reason}}
        end
        |> format_token_error(pointer)

      token ->
        format_token_error({:error, {"#{inspect(token)}", :invalid_token}}, pointer)
    end
  end

  @doc """
  Processes a JSON Pointer into a list of tokens.
  """
  @spec process(pointer :: String.t()) :: [String.t()]
  def process(pointer) do
    pointer
    |> String.split("/")
    |> Enum.map(&preprocess_token/1)
  end

  defp format_token_error({:error, {token, reason}}, pointer) do
    {:error, "error resolving token `#{token}` in `#{pointer}`: #{reason}"}
  end

  defp format_token_error(x, _pointer), do: x

  @spec preprocess_token(String.t()) :: String.t()
  defp preprocess_token(token) do
    token
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  @spec resolve_token(json(), String.t(), boolean()) ::
          {:ok, json()} | {:error, {String.t(), atom()}}
  defp resolve_token(object, token, allow_array_append) do
    token = preprocess_token(token)

    case object do
      object when is_map(object) ->
        if Map.has_key?(object, token) do
          {:ok, Map.get(object, token)}
        else
          {:error, {token, :not_found}}
        end

      object when is_list(object) ->
        case token do
          "-" when allow_array_append ->
            {:ok, token}

          token ->
            cond do
              String.match?(token, ~r/\d+/) ->
                index = String.to_integer(token)

                if index < length(object) do
                  {:ok, Enum.at(object, index)}
                else
                  {:error, {token, :index_out_of_bounds}}
                end

              token == "-" ->
                {:error, {token, :append_not_allowed}}

              true ->
                {:error, {token, :invalid_array_index}}
            end
        end

      ^object ->
        {:error, {token, :invalid_object}}
    end
  end
end
