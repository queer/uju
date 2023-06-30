defmodule Server.Internal.SendQuery.Op do
  alias Server.Internal.SendQuery.Compiler.{BooleanOp, LogicalOp}

  defmacro compile_boolean_op(op_name) do
    quote do
      defp compile_op(
             %{
               "op" => unquote(op_name),
               "path" => path,
               "value" => %{"value" => _} = value
             } = op
           )
           when Server.Internal.SendQuery.Op.is_boolean_op(op) do
        %BooleanOp{
          op: unquote(op_name),
          path: path,
          value: value
        }
      end

      defp compile_op(
             %{
               "op" => unquote(op_name),
               "path" => path,
               "value" => %{"path" => _} = value
             } = op
           )
           when Server.Internal.SendQuery.Op.is_boolean_op(op) do
        %BooleanOp{
          op: unquote(op_name),
          path: path,
          value: value
        }
      end
    end
  end

  defmacro compile_logical_op(op_name) do
    quote location: :keep do
      require OK

      defp compile_op(
             %{
               "op" => unquote(op_name),
               "value" => value
             } = op
           )
           when Server.Internal.SendQuery.Op.is_boolean_op(op) do
        value = Enum.map(value, &compile_op/1)

        OK.assert! do
          Enum.all?(value, fn op ->
            match?(%BooleanOp{}, op)
          end) or
            Enum.all?(value, fn op ->
              match?(%LogicalOp{}, op)
            end)
        end

        %LogicalOp{
          op: unquote(op_name),
          value: value
        }
      end
    end
  end

  defguard is_boolean_op(maybe_op)
           # op is map
           # op["op"] is string
           # op["path"] is string
           # op["value"] is map and has key "value" or "path"
           when is_map(maybe_op) and is_binary(:erlang.map_get("op", maybe_op)) and
                  is_binary(:erlang.map_get("path", maybe_op)) and
                  is_map(:erlang.map_get("value", maybe_op)) and
                  (:erlang.is_map_key("value", :erlang.map_get("value", maybe_op)) or
                     :erlang.is_map_key("path", :erlang.map_get("value", maybe_op)))

  defguard is_logical_op(maybe_op)
           # op is map
           # op["op"] is string
           # op["value"] is list
           when is_map(maybe_op) and is_binary(:erlang.map_get("op", maybe_op)) and
                  is_list(:erlang.map_get("value", maybe_op))
end
