defmodule Server.Plugin do
  alias Server.Protocol.V1

  @type callback_result() :: :ok | {:ok, any()} | {:error, any()} | plugin_control()
  @type plugin_control() :: :ignore | :halt

  @callback init() :: :ok | {:error, any()}

  @callback handle_message_before(session :: pid(), message :: any()) ::
              callback_result()

  @callback handle_send_v1(session :: pid(), message :: V1.SendPayload.t()) ::
              callback_result()

  @callback handle_message_after(session :: pid(), message :: any()) ::
              callback_result()

  @callback name() :: String.t()

  @callback description() :: String.t()

  @callback version() :: Version.t()
end
