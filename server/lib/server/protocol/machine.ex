defmodule Server.Protocol.V1.Machine do
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

  @codes %{
    auth_success: 0,
    auth_fail: 1,
    configure_success: 2
  }

  @messages %{
    auth_success: "auth success",
    auth_fail: "auth fail",
    configure_success: "config success"
  }

  def init_session(config) do
    session_id = "test"

    {:ok, session} =
      Session.start_link(%{
        config: config,
        session_id: session_id
      })

    send(session, {:out, _p(:HELLO, %HelloPayload{session: session_id, heartbeat: 10_000})})

    {:ok, session_id}
  end

  @spec process_message(pid(), Payload.t()) :: :ok | {:error, :invalid_client_payload}
  def process_message(session, %Payload{payload: payload}) do
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
       _p(:SERVER_MESSAGE, %ServerMessagePayload{
         code: @codes[:auth_success],
         message: @messages[:auth_success],
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
       _p(:RECEIVE, %ReceivePayload{
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
       _p(:PONG, %PongPayload{
         nonce: nonce
       })}
    )

    :ok
  end

  defp handle_configure(session, %ConfigurePayload{
         scope: "session",
         config: %SessionConfig{} = config
       }) do
    send(:session, {:configure, config})

    send(
      :session,
      {:out,
       _p(:SERVER_MESSAGE, %ServerMessagePayload{
         code: @codes[:config_success],
         message: @messages[:config_success],
         extra: nil,
         layer: "protocol"
       })}
    )
  end

  defp _p(op, out) do
    %Payload{
      opcode: op,
      payload: out,
      _: %{
        ts: :erlang.system_time(:millisecond)
      }
    }
  end
end
