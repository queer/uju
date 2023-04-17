defmodule Server.Protocol.V1.Machine do
  alias Server.Protocol.V1
  alias Server.Protocol.V1.Session

  alias Server.Protocol.V1.{
    Payload,
    HelloPayload,
    AuthenticatePayload,
    ServerMessagePayload,
    SendPayload,
    ReceivePayload,
    PingPayload,
    PongPayload,
    ConfigurePayload,
    SendImmediateConfig,
    SendLaterConfig,
    SessionConfig
  }

  def init_session(config) do
    session_id = "test"

    {:ok, session} =
      Session.start_link(%{
        config: config,
        session_id: session_id
      })

    send(
      session,
      {:out, V1.build(:HELLO, %HelloPayload{session: session_id, heartbeat: 10_000})}
    )

    {:ok, session_id}
  end

  @spec process_message(atom() | pid(), Payload.t()) :: :ok | {:error, :invalid_client_payload}
  def process_message(session, payload) when is_atom(session) do
    session |> Process.whereis() |> process_message(payload)
  end

  def process_message(session, %Payload{payload: payload}) when is_pid(session) do
    case payload do
      %AuthenticatePayload{} ->
        handle_authenticate(session, payload)

      %SendPayload{} ->
        handle_send(session, payload)

      %PingPayload{} ->
        handle_ping(session, payload)

      %ConfigurePayload{} ->
        handle_configure(session, payload)

      _ ->
        {:error, :invalid_client_payload}
    end
  end

  defp handle_authenticate(session, _payload) do
    # TODO: Real auth

    send(
      session,
      {:out,
       V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
         code: V1.codes()[:auth_success],
         message: V1.messages()[:auth_success],
         extra: nil,
         layer: "protocol"
       })}
    )

    :ok
  end

  defp handle_send(session, %SendPayload{config: config, data: data}) do
    send(
      session,
      {:out,
       V1.build(:RECEIVE, %ReceivePayload{
         nonce: config.nonce,
         data: data,
         _: %{
           pid: "#{inspect(session)}"
         }
       })}
    )

    :ok
  end

  defp handle_ping(session, %PingPayload{nonce: nonce}) do
    send(
      session,
      {:out,
       V1.build(:PONG, %PongPayload{
         nonce: nonce
       })}
    )

    :ok
  end

  defp handle_configure(session, %ConfigurePayload{
         scope: "session",
         config: %SessionConfig{} = config
       }) do
    send(session, {:configure, config})

    send(
      session,
      {:out,
       V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
         code: V1.codes()[:configure_success],
         message: V1.messages()[:configure_success],
         extra: nil,
         layer: "protocol"
       })}
    )
  end
end
