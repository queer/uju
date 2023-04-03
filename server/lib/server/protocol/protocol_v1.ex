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

  ## Sessions ##

  typedstruct module: SessionConfig do
    field(:format, binary())
    field(:compression, binary())
  end

  defproto!(SessionConfig, %{format: :string, compression: :string})

  typedstruct module: GroupConfig do
    field(:max_size, pos_integer())
    field(:max_age, pos_integer())
    field(:replication, binary())
  end

  defproto!(GroupConfig, %{
    max_size: :pos_integer,
    max_age: :pos_integer,
    replication: {:any, ["none", "dc", "region"]}
  })

  typedstruct module: GlobalSessionConfig do
    field(:max_size, pos_integer())
    field(:max_age, pos_integer())
    field(:replication, binary())
  end

  defproto!(GlobalSessionConfig, %{
    max_size: :pos_integer,
    max_age: :pos_integer,
    replication: ["none", "dc", "region"]
  })

  ## Config ##

  typedstruct module: SendImmediateConfig do
    field(:nonce, binary())
    field(:await_reply, boolean(), default: false)
  end

  defproto!(SendImmediateConfig, %{nonce: :string, await_reply: {:optional, :boolean}}, %{
    await_reply: false
  })

  typedstruct module: SendLaterConfig do
    field(:group, :binary)
  end

  defproto!(SendLaterConfig, %{group: :string})

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
  end

  defproto!(SendPayload, %{
    method: {:any, ["immediate", "later"]},
    data: :any,
    config: {:any, [Server.Protocol.V1.SendImmediateConfig, Server.Protocol.V1.SendLaterConfig]}
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
    field(:target, binary())

    field(
      :config,
      Server.Protocol.V1.SessionConfig.t()
      | Server.Protocol.V1.GroupConfig.t()
      | Server.Protocol.V1.GlobalSessionConfig.t()
    )
  end

  defproto!(ConfigurePayload, %{
    target: :string,
    config:
      {:any,
       [
         __MODULE__.SessionConfig,
         __MODULE__.GroupConfig,
         __MODULE__.GlobalSessionConfig
       ]}
  })
end
