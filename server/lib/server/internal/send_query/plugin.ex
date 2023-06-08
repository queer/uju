defmodule Server.Internal.SendQuery.Plugin do
  @behaviour Server.Plugin

  alias Server.Protocol.V1

  @impl true
  def init(_config) do
    {:ok, nil}
  end

  @impl true
  def handle_message_before(_session, _message) do
    :ok
  end

  @impl true
  def handle_send_v1(session, %V1.SendPayload{config: config, data: data}) do
    send(
      session,
      {:out,
       V1.build(:RECEIVE, %V1.ReceivePayload{
         nonce: config.nonce,
         data: data,
         _: %{
           pid: "#{inspect(session)}"
         }
       })}
    )

    :ok
  end

  @impl true
  def handle_message_after(_session, _message) do
    :ok
  end
end
