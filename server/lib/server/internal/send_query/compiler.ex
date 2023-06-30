defmodule Server.Internal.SendQuery.Compiler do
  use TypedStruct
  import Server.Internal.SendQuery.Op
  alias Server.Plugins.Pointer
  alias Server.Protocol.V1
  require Server.Internal.SendQuery.Op
  require OK

  @type ops() :: logical_ops() | boolean_ops()
  @type path() :: String.t()

  @type boolean_ops() ::
          :"$eq"
          | :"$ne"
          | :"$gt"
          | :"$gte"
          | :"$lt"
          | :"$lte"
          | :"$in"
          | :"$nin"
          | :"$contains"
          | :"$ncontains"
          | :"$exists"
  @type logical_ops() :: :"$and" | :"$or" | :"$not" | :"$xor"

  @type ordering() :: :"$asc" | :"$desc"

  @type with_type() :: with_path() | with_value()
  @type with_path() :: %{path: String.t()}
  @type with_value() :: %{value: Pointer.json()}

  typedstruct module: Query do
    alias Server.Internal.SendQuery.Compiler

    field(:_debug, map())
    field(:filter, [Compiler.BooleanOp.t() | Compiler.LogicalOp.t()])
    field(:select, Selector.t() | nil)
  end

  typedstruct module: BooleanOp do
    alias Server.Internal.SendQuery.Compiler

    field(:op, Compiler.boolean_ops())
    field(:path, String.t())
    field(:value, Compiler.with_type())
  end

  typedstruct module: LogicalOp do
    alias Server.Internal.SendQuery.Compiler

    field(:op, Compiler.logical_ops())

    field(:value, [Compiler.BooleanOp.t()] | [Compiler.LogicalOp.t()])
  end

  typedstruct module: Selector do
    alias Server.Internal.SendQuery.Compiler

    field(:limit, pos_integer() | nil)
    field(:ordering, [%{required(Compiler.ordering()) => String.t()}])
  end

  def compile(%V1.MetadataQuery{_debug: debug, filter: filter, select: select} = query) do
    # TODO: This needs to get values a LOT more defensively
    %__MODULE__.Query{
      _debug: debug,
      filter: Enum.map(filter, &compile_op/1),
      select: %__MODULE__.Selector{
        limit: select["limit"] || nil,
        ordering: select["ordering"] || []
      }
    }
  end

  for op <- [
        "$eq",
        "$ne",
        "$gt",
        "$gte",
        "$lt",
        "$lte",
        "$in",
        "$nin",
        "$contains",
        "$ncontains",
        "$exists"
      ] do
    compile_boolean_op(op)
  end

  for op <- [
        "$and",
        "$or",
        "$not",
        "$xor"
      ] do
    compile_logical_op(op)
  end
end
