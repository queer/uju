defmodule Server.Protocol.V1 do
  alias __MODULE__.SendPayload
  use TypedStruct
  import Server.Protocol.Parser

  @type payload_body() ::
          __MODULE__.HelloPayload.t()
          | __MODULE__.AuthenticatePayload.t()
          | __MODULE__.ServerMessagePayload.t()
          | __MODULE__.SendPayload.t()
          | __MODULE__.ReceivePayload.t()
          | __MODULE__.PingPayload.t()
          | __MODULE__.PongPayload.t()
          | __MODULE__.ConfigurePayload.t()

  @opcodes [
    "HELLO",
    "AUTHENTICATE",
    "SERVER_MESSAGE",
    "SEND",
    "RECEIVE",
    "PING",
    "PONG",
    "CONFIGURE"
  ]

  @codes %{
    _response_status_failure: -2,
    _response_status_success: -1,
    auth_success: 0,
    auth_fail: 1,
    configure_success: 2,
    parse_fail: 3,
    invalid_client_payload: 4
  }

  @messages %{
    _response_status_failure: "failure",
    _response_status_success: "success",
    auth_success: "auth success",
    auth_fail: "auth fail",
    configure_success: "config success",
    parse_fail: "parse fail",
    invalid_client_payload: "invalid client payload"
  }

  def opcodes, do: @opcodes
  def codes, do: @codes
  def messages, do: @messages

  ## Sessions ##

  typedstruct module: SessionConfig do
    field(:format, binary())
    field(:compression, binary())
    field(:metadata, map() | nil)
    field(:replication, binary())
  end

  defproto!(
    SessionConfig,
    %{
      format: {:optional, {:any, ["json", "msgpack"]}},
      compression: {:optional, {:any, ["none", "zstd"]}},
      metadata: :map,
      replication: {:optional, {:any, ["none", "dc", "region"]}}
    },
    %{
      format: "json",
      compression: "none",
      replication: "none"
    }
  )

  ## Config ##

  typedstruct module: SendImmediateConfig do
    field(:nonce, binary())
    field(:await_reply, boolean(), default: false)
  end

  defproto!(SendImmediateConfig, %{nonce: :string, await_reply: {:optional, :boolean}}, %{
    await_reply: false
  })

  typedstruct module: SendLaterConfig do
    field(:group, binary())
  end

  defproto!(SendLaterConfig, %{group: :string})

  ## Queries ##

  typedstruct module: MetadataSelect do
    field(:ordering, [%{required(String.t()) => String.t()}] | nil)
    field(:limit, pos_integer() | nil)
  end

  defproto!(MetadataSelect, %{ordering: :list, limit: :pos_integer})

  # TODO: MetadataQuery.filter should do better than {:optional, :list}

  typedstruct module: MetadataQuery do
    field(:_debug, map())
    field(:filter, [%{required(String.t()) => any()}])
    field(:select, Server.Protocol.V1.MetadataSelect.t() | nil)
  end

  defproto!(MetadataQuery, %{
    _debug: :map,
    filter: {:optional, :list},
    select: {:optional, Server.Protocol.V1.MetadataSelect}
  })

  ## Payloads ##

  typedstruct module: Payload do
    field(:opcode, binary())
    field(:payload, Server.Protocol.V1.payload_body())
    field(:_, any())
  end

  defproto!(Payload, %{
    opcode: {:any, @opcodes},
    payload:
      {:any,
       [
         __MODULE__.HelloPayload,
         __MODULE__.AuthenticatePayload,
         __MODULE__.ServerMessagePayload,
         __MODULE__.SendPayload,
         __MODULE__.ReceivePayload,
         __MODULE__.PingPayload,
         __MODULE__.PongPayload,
         __MODULE__.ConfigurePayload
       ]},
    _: :any
  })

  typedstruct module: HelloPayload do
    field(:session, binary())
    field(:heartbeat, non_neg_integer())
  end

  defproto!(HelloPayload, %{session: :string, heartbeat: :non_neg_integer})

  typedstruct module: AuthenticatePayload do
    field(:auth, any())
    field(:config, Server.Protocol.V1.SessionConfig.t())
  end

  defproto!(AuthenticatePayload, %{auth: :any, config: Server.Protocol.V1.SessionConfig})

  typedstruct module: ServerMessagePayload do
    field(:code, non_neg_integer())
    field(:message, binary())
    field(:extra, any())
    field(:layer, binary())
  end

  defproto!(ServerMessagePayload, %{
    code: :non_neg_integer,
    message: :string,
    extra: :any,
    layer: {:any, ["protocol", "application"]}
  })

  typedstruct module: SendPayload do
    field(:method, binary())
    field(:data, any())

    field(
      :config,
      Server.Protocol.V1.SendImmediateConfig.t() | Server.Protocol.V1.SendLaterConfig.t() | nil
    )

    field(:query, Server.Protocol.V1.MetadataQuery.t())
  end

  defproto!(SendPayload, %{
    method: {:any, ["immediate", "later"]},
    data: :any,
    config: {:any, [Server.Protocol.V1.SendImmediateConfig, Server.Protocol.V1.SendLaterConfig]},
    query: Server.Protocol.V1.MetadataQuery
  })

  typedstruct module: ReceivePayload do
    field(:nonce, binary() | nil)
    field(:data, any())
    field(:_, any())
  end

  defproto!(ReceivePayload, %{
    nonce: {:any, [:string, nil]},
    data: :any,
    _: :any
  })

  typedstruct module: PingPayload do
    field(:nonce, binary())
  end

  defproto!(PingPayload, %{nonce: :string})

  typedstruct module: PongPayload do
    field(:nonce, binary())
    field(:session_size, non_neg_integer())
  end

  defproto!(PongPayload, %{nonce: :string, session_size: :non_neg_integer})

  typedstruct module: ConfigurePayload do
    field(:scope, binary())
    field(:config, Server.Protocol.V1.SessionConfig.t())
  end

  defproto!(ConfigurePayload, %{
    scope: {:any, ["session"]},
    config: __MODULE__.SessionConfig
  })

  ## Helpers ##

  def build(op, out) do
    %__MODULE__.Payload{
      opcode: op,
      payload: out,
      _: %{
        ts: :erlang.system_time(:millisecond)
      }
    }
  end
end
