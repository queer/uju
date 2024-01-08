defmodule Server.Internal.V1.SendQuery.Compiler do
  use TypedStruct
  import Server.Internal.V1.SendQuery.Op
  alias Server.Plugins.Pointer
  alias Server.Protocol.V1
  require Server.Internal.V1.SendQuery.Op
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
  @type with_path() :: %{path: Pointer.json()}
  @type with_value() :: %{value: any()}

  typedstruct module: Query do
    alias Server.Internal.V1.SendQuery.Compiler

    field(:_debug, map())
    field(:filter, [Compiler.BooleanOp.t() | Compiler.LogicalOp.t()])
    field(:select, Selector.t() | nil)
  end

  typedstruct module: BooleanOp do
    alias Server.Internal.V1.SendQuery.Compiler

    field(:op, Compiler.boolean_ops())
    field(:path, String.t())
    field(:value, Compiler.with_type())
  end

  typedstruct module: LogicalOp do
    alias Server.Internal.V1.SendQuery.Compiler

    field(:op, Compiler.logical_ops())

    field(:value, [Compiler.BooleanOp.t()] | [Compiler.LogicalOp.t()])
  end

  typedstruct module: Selector do
    alias Server.Internal.V1.SendQuery.Compiler

    field(:limit, pos_integer() | nil)
    field(:ordering, [%{required(Compiler.ordering()) => String.t()}])
  end

  def compile(%V1.MetadataQuery{_debug: debug, filter: filter, select: select}) do
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

  Enum.map(
    [
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
    ],
    &compile_boolean_op/1
  )

  Enum.map(
    [
      "$and",
      "$or",
      "$not",
      "$xor"
    ],
    &compile_logical_op/1
  )
end
