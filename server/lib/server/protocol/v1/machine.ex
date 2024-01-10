defmodule Server.Protocol.V1.Machine do
  alias Server.Plugins

  alias Server.Protocol.V1
  alias Server.Protocol.V1.Session

  alias Server.Protocol.V1.{
    Payload,
    HelloPayload,
    AuthenticatePayload,
    ServerMessagePayload,
    SendPayload,
    PingPayload,
    PongPayload,
    ConfigurePayload,
    SessionConfig
  }

  @heartbeat_interval Application.compile_env(:server, :sessions)[:heartbeat_interval]

  def init_session(config, parent \\ nil) do
    session_id = generate_session_id()

    {:ok, session} =
      Session.start_link(%{
        config: config,
        session_id: session_id,
        parent: parent,
        heartbeat_interval: @heartbeat_interval
      })

    V1.Session.send_outgoing_message(
      session,
      V1.build(:HELLO, %HelloPayload{session: session_id, heartbeat: @heartbeat_interval})
    )

    {:ok, session, session_id}
  end

  defp generate_session_id do
    hex = for(_ <- 0..16, do: Integer.to_string(:rand.uniform(256), 16), into: <<>>)

    hex
    |> String.downcase()
    |> List.wrap()
    |> List.insert_at(0, "0x")
    |> Enum.join()
  end

  @spec process_message(pid(), Payload.t()) :: :ok
  def process_message(session, %Payload{payload: payload} = message) when is_pid(session) do
    Plugins.invoke_only(Plugins.V1, :handle_message_before, [session, message])

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
        payload =
          V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
            code: V1.codes()[:invalid_client_payload],
            message: V1.messages()[:invalid_client_payload],
            extra: %{
              payload: payload
            },
            layer: "protocol"
          })

        V1.Session.send_outgoing_message(session, payload)
        :ok
    end

    Plugins.invoke_only(Plugins.V1, :handle_message_after, [session, message])
  end

  defp handle_authenticate(session, _payload) do
    # TODO: Real auth

    Plugins.invoke_only(Plugins.V1, :handle_connect, [session])

    V1.Session.finish_auth(session)

    V1.Session.send_outgoing_message(
      session,
      V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
        code: V1.codes()[:auth_success],
        message: V1.messages()[:auth_success],
        extra: nil,
        layer: "protocol"
      })
    )

    :ok
  end

  defp handle_send(session, %SendPayload{} = payload) do
    Plugins.invoke_only(Plugins.V1, :handle_send, [session, payload])
    :ok
  end

  defp handle_ping(session, %PingPayload{nonce: nonce}) do
    V1.Session.send_outgoing_message(
      session,
      V1.build(:PONG, %PongPayload{
        nonce: nonce
      })
    )

    :ok
  end

  defp handle_configure(
         session,
         %ConfigurePayload{
           config: %SessionConfig{} = config
         } = message
       ) do
    V1.Session.configure(session, config)

    Plugins.invoke_only(Plugins.V1, :handle_configure, [session, message])

    V1.Session.send_outgoing_message(
      session,
      V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
        code: V1.codes()[:configure_success],
        message: V1.messages()[:configure_success],
        extra: nil,
        layer: "protocol"
      })
    )
  end

  def heartbeat_interval, do: @heartbeat_interval
end
