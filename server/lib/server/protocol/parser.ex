defmodule Server.Protocol.Parser do
  @doc """
  a schema may be a map of any of the following:
  - :integer
  - :pos_integer
  - :non_neg_integer
  - :string
  - :map
  - :list
  - :any
  - nil
  - a list of any possible values
  - a map of field names to any possible values
  - a module that has a protocol parser derived
  """
  defmacro defproto!(mod, schema) do
    quote location: :keep do
      unless is_map(unquote(schema)) do
        raise ArgumentError, """
        schema must be a map, got:
            #{inspect(unquote(schema), pretty: true)}
        """
      end

      fields =
        Server.Protocol.Parser.__get_expected_fields_from_source_file__(
          __ENV__.file,
          unquote(mod)
        )

      missing_fields =
        MapSet.difference(MapSet.new(fields), MapSet.new(Map.keys(unquote(schema))))

      if MapSet.size(missing_fields) > 0 do
        raise ArgumentError, """
        missing fields in schema:
            #{inspect(missing_fields, pretty: true)}
        """
      end

      defimpl Jason.Encoder, for: unquote(mod) do
        def encode(struct, opts) do
          Jason.Encode.map(Map.from_struct(struct), opts)
        end
      end

      def __schema__(unquote(mod)), do: unquote(schema)

      def parse(unquote(mod), input) do
        schema = unquote(schema)

        unless is_map(input) do
          raise ArgumentError, """
          input must be a map, got:
              #{inspect(input, pretty: true)}
          """
        end

        my_fields =
          Server.Protocol.Parser.__get_expected_fields_from_source_file__(
            __ENV__.file,
            unquote(mod)
          )

        missing_fields =
          MapSet.difference(
            MapSet.new(my_fields),
            MapSet.new(Map.keys(input))
          )

        if MapSet.size(missing_fields) > 0 do
          raise ArgumentError, """
          missing fields in input:
              #{inspect(missing_fields, pretty: true)}
          """
        end

        if __validate__(schema, input) do
          __recursively_add_modules_to_maps__(schema, unquote(mod), input, [])
        else
          raise """
          input
              #{inspect(input, pretty: true)}
          did not validate against schema:
              #{inspect(schema, pretty: true)}
          """
        end
      end

      if not Module.defines?(__MODULE__, {:__validate__, 2}) do
        @non_module_types [
          :any,
          :integer,
          :non_neg_integer,
          :pos_integer,
          :string,
          :boolean,
          nil
        ]

        defp __validate__(schema, input) do
          case schema do
            :integer ->
              is_integer(input)

            :pos_integer ->
              is_integer(input) and input > 0

            :non_neg_integer ->
              is_integer(input) and input >= 0

            :string ->
              is_binary(input)

            :map ->
              is_map(input)

            :list ->
              is_list(input)

            nil ->
              is_nil(input)

            :any ->
              true

            :boolean ->
              input in [true, false]

            binary when is_binary(binary) ->
              input == binary

            list when is_list(list) ->
              Enum.any?(list, &__validate__(schema, &1))

            map when is_map(map) ->
              Enum.all?(map, fn {key, value} ->
                input_value =
                  cond do
                    is_binary(key) ->
                      input[key]

                    is_atom(key) ->
                      input[Atom.to_string(key)]
                  end

                __validate__(value, input_value)
              end)

            mod when is_atom(mod) ->
              __validate__(__schema__(mod), input)

            {:any, options} when is_list(options) ->
              Enum.any?(options, &__validate__(&1, input))
          end
        end
      end

      def __recursively_add_modules_to_maps__(schema, unquote(mod), input, path)
          when is_map(input) do
        input
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          schema_value =
            cond do
              is_binary(key) ->
                schema[String.to_existing_atom(key)]

              is_atom(key) ->
                schema[key]
            end

          possible_schema_mod =
            case schema_value do
              schema_mod
              when is_atom(schema_mod) and
                     schema_mod not in @non_module_types ->
                [schema_mod]

              {:any, options} when is_list(options) ->
                Enum.filter(options, fn x -> is_atom(x) and x not in @non_module_types end)

              _ ->
                []
            end

          case possible_schema_mod do
            [] ->
              Map.put(acc, key, value)

            schema_mods ->
              # find the first module where the schema keys match the input keys, ignoring ordering
              # if none match, then raise
              # if more than one match, then raise

              matching_mod =
                Enum.filter(schema_mods, fn schema_mod ->
                  schema = __schema__(schema_mod)

                  schema
                  |> Map.keys()
                  |> Enum.reject(&(&1 == :_))
                  |> Enum.map(&Atom.to_string/1)
                  |> MapSet.new()
                  |> MapSet.difference(MapSet.new(Map.keys(value)))
                  |> MapSet.size()
                  |> Kernel.==(0)
                end)

              case matching_mod do
                [] ->
                  raise ArgumentError, """
                  no matching schema found for input:
                      #{inspect(value, pretty: true)}
                  """

                [schema_mod] ->
                  next_value =
                    schema_mod
                    |> __schema__()
                    |> __recursively_add_modules_to_maps__(unquote(mod), value, path ++ [key])
                    |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), v} end)
                    |> Map.put(:__struct__, schema_mod)

                  Map.put(acc, key, next_value)

                schema_mods ->
                  raise ArgumentError, """
                  multiple matching schemas found for input:
                      #{inspect(value, pretty: true)}
                  """
              end
          end
        end)
        |> case do
          out when path == [] ->
            out
            |> Enum.into(%{}, fn {key, value} -> {String.to_existing_atom(key), value} end)
            |> Map.put(:__struct__, unquote(mod))

          out ->
            out
        end
      end

      def __recursively_add_modules_to_maps__(schema, unquote(mod), input, path)
          when is_list(input) do
        Enum.map(input, fn value ->
          __recursively_add_modules_to_maps__(schema, unquote(mod), value, path)
        end)
      end

      def __recursively_add_modules_to_maps__(schema, unquote(mod), input, path)
          when is_binary(input) do
        input
      end
    end
  end

  def __get_expected_fields_from_source_file__(source, mod) do
    expected_mod =
      mod
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.reverse()
      |> hd()
      |> String.to_atom()

    {:ok, {:defmodule, _, [{:__aliases__, _, _} | body]}} =
      source
      |> File.read!()
      |> Code.string_to_quoted()

    [[do: {:__block__, _, body}]] = body

    body
    |> Enum.filter(fn x ->
      match?({:typedstruct, _, [[module: {:__aliases__, _, [^expected_mod]}] | _]}, x)
    end)
    |> Enum.map(fn
      {:typedstruct, _, [_ts_config, [do: {:__block__, _, block}]]} -> block
      {:typedstruct, _, [_ts_config, [do: {:field, meta, field}]]} -> [{:field, meta, field}]
    end)
    |> Enum.flat_map(fn fields ->
      fields
      |> Enum.map(fn {:field, _, [name | _]} -> name end)
    end)
  end
end
