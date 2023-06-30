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
  defmacro defproto!(mod, schema, defaults \\ {:%{}, [line: 0], []}) do
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
        @impl true
        def encode(struct, opts) do
          Jason.Encode.map(Map.from_struct(struct), opts)
        end
      end

      defimpl Msgpax.Packer, for: unquote(mod) do
        @impl true
        def pack(term) do
          Msgpax.pack!(Map.from_struct(term))
        end
      end

      def __schema__(unquote(mod)), do: unquote(schema)

      def __defaults__(unquote(mod)), do: unquote(defaults)

      # @spec parse(module(), any()) :: {:ok, any()} | {:error, atom(), {map(), any()}}
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
          schema
          |> __recursively_add_modules_to_maps__(unquote(mod), input, [])
          |> __recursively_apply_defaults__(unquote(mod))
          |> OK.ok()
        else
          {:error, :invalid_input, %{schema: schema, input: input}}
        end
      end

      defp __recursively_apply_defaults__(map, unquote(mod)) when is_map(map) and map == %{} do
        %{}
      end

      defp __recursively_apply_defaults__(%{__struct__: _} = data, unquote(mod)) do
        struct = data.__struct__

        data = Map.from_struct(data)

        defaults = __defaults__(struct)
        data = Map.merge(defaults, data)

        data
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          cond do
            is_map(value) ->
              Map.put(acc, key, __recursively_apply_defaults__(value, unquote(mod)))

            is_list(value) ->
              Map.put(
                acc,
                key,
                Enum.map(value, &__recursively_apply_defaults__(&1, unquote(mod)))
              )

            true ->
              Map.put(acc, key, value)
          end
        end)
        |> Map.put(:__struct__, struct)
      end

      defp __recursively_apply_defaults__(map, unquote(mod))
           when is_map(map) and map != %{} do
        map
      end

      if not Module.defines?(__MODULE__, {:__validate__, 2}) do
        @non_module_types [
          :any,
          :integer,
          :non_neg_integer,
          :pos_integer,
          :string,
          :boolean,
          :map,
          :list,
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

            {:optional, type} ->
              is_nil(input) or __validate__(type, input)
          end
        end

        def resolve_schema_value(schema_value) do
          case schema_value do
            mod when is_atom(mod) and mod not in @non_module_types ->
              [mod]

            {:any, options} when is_list(options) ->
              Enum.flat_map(options, &resolve_schema_value/1)

            {:optional, type} ->
              resolve_schema_value(type)

            _ ->
              []
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

          optional? = match?({:optional, _}, schema_value)
          possible_schema_mod = resolve_schema_value(schema_value)

          case possible_schema_mod do
            [] ->
              Map.put(acc, key, value)

            schema_mods when is_list(schema_mods) ->
              # find the first module where the schema keys match the input keys, ignoring ordering
              # if none match, then raise
              # if more than one match, then raise

              matching_mod =
                if optional? and value == nil do
                  []
                else
                  Enum.filter(schema_mods, fn schema_mod ->
                    schema = __schema__(schema_mod)

                    optional_key_count =
                      schema
                      |> Map.values()
                      |> Enum.filter(&match?({:optional, _}, &1))
                      |> Enum.count()

                    schema
                    |> Map.keys()
                    |> Enum.reject(&(&1 == :_))
                    |> Enum.map(&Atom.to_string/1)
                    |> MapSet.new()
                    |> MapSet.difference(MapSet.new(Map.keys(value)))
                    |> MapSet.size()
                    |> Kernel.<=(optional_key_count)
                  end)
                end

              case matching_mod do
                [] when value != nil ->
                  raise ArgumentError, """
                  no matching schema found for input:
                      #{inspect(value, pretty: true)}
                  """

                [] when value == nil ->
                  Map.put(acc, key, value)

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
