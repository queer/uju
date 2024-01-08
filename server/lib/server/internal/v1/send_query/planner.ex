defmodule Server.Internal.V1.SendQuery.Planner do
  use TypedStruct
  alias Server.Internal.V1.SendQuery.Compiler

  typedstruct module: Query do
    field(:from, Compiler.Query.t())
    field(:plan, Server.Internal.V1.SendQuery.Planner.Plan.t())
  end

  typedstruct module: Plan do
    field(:query, Lethe.Query.t())
    field(:ordering, [%{required(Compiler.ordering()) => String.t()}])
  end

  def plan(%Compiler.Query{} = query) do
    # compile internal ops into Lethe ops

    lethe_ops =
      query.filter
      |> Enum.map(fn
        %Compiler.BooleanOp{op: op} = filter ->
          lethe_op =
            case op do
              "$eq" ->
                :==

              "$ne" ->
                :!=

              "$gt" ->
                :>

              "$gte" ->
                :>=

              "$lt" ->
                :<

              "$lte" ->
                :<=

              other ->
                raise "not yet implemented: #{inspect(other, pretty: true)}"
                # TODO: implement these
                # "$in" -> :in
                # "$nin" -> :not_in
                # "$contains" -> :contains
                # "$ncontains" -> :not_contains
                # "$exists" -> :exists
            end

          [first_part | rest] =
            filter.path
            |> String.trim_leading("/")
            |> String.split("/")

          mnesia_path_query =
            Enum.reduce(rest, Lethe.Ops.map_get(first_part, :metadata), fn x, acc ->
              Lethe.Ops.map_get(x, acc)
            end)

          # TODO: atom-ify this
          mnesia_value_query =
            case filter.value do
              %{"value" => value} ->
                value

              %{"path" => path} ->
                Enum.reduce(path, Lethe.Ops.map_get(first_part, :metadata), fn x, acc ->
                  Lethe.Ops.map_get(x, acc)
                end)
            end

          apply(Lethe.Ops, lethe_op, [mnesia_path_query, mnesia_value_query])

        %Compiler.LogicalOp{op: _op} = filter ->
          raise "not yet implemented: #{inspect(filter, pretty: true)}"
      end)

    lethe_query = Emit.query()

    lethe_query =
      lethe_ops
      |> Enum.reduce(lethe_query, fn op, acc ->
        Lethe.where_raw(acc, op)
      end)
      |> Lethe.limit(query.select.limit || :all)
      |> Lethe.select(:pid)

    %__MODULE__.Query{
      from: query,
      plan: %__MODULE__.Plan{
        query: lethe_query,
        ordering: query.select.ordering
      }
    }
  end
end
