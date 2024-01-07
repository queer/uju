defmodule Server.External.RestAPIV1 do
  use Plug.Router
  import Server.External.V1Payloads
  alias Server.Protocol.V1
  alias Server.Protocol.V1.ServerMessagePayload

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  defmacrop with_payload(conn, expected_payload, do: do_block) do
    quote do
      conn = unquote(conn)

      case V1.parse(unquote(expected_payload), conn.body_params) do
        {:ok, var!(payload)} ->
          unquote(do_block)

        {:error, :invalid_input, %{schema: schema, input: input}} ->
          payload =
            V1.build(:SERVER_MESSAGE, %ServerMessagePayload{
              code: V1.codes()[:parse_fail],
              message: V1.messages()[:parse_fail],
              extra: %{
                schema: schema,
                input: input
              },
              layer: "protocol"
            })

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(400, Jason.encode!(payload))
      end
    end
  end

  get "/socket" do
    conn = fetch_query_params(conn)

    conn
    |> WebSockAdapter.upgrade(
      Server.External.V1WebsockHandler,
      # TODO: Validate these params
      %{
        format: Map.get(conn.query_params, "format", "json"),
        compression: Map.get(conn.query_params, "compression", "none"),
        metadata: %{},
        session_id: Map.get(conn.query_params, "session")
      },
      early_validate_upgrade: true,
      compress: false
    )
    |> halt()
  end

  post "/start-session" do
    do_start_session(conn)
  end

  defp do_start_session(conn) do
    with_payload(conn, V1.SessionConfig) do
      {:ok, _session, session_id} = V1.Machine.init_session(payload)
      json(conn, ok_payload(session_id))
    end
  end

  post "/send" do
    auth_header = Enum.find(conn.req_headers, fn {k, _} -> k == "authorization" end)

    case auth_header do
      {"authorization", "Session " <> session_id} ->
        {:ok, session} = V1.Session.lookup_session(session_id)

        conn
        |> assign(:session, session)
        |> assign(:session_id, session_id)
        |> process_payload()

      _ ->
        json(conn, error_payload(:invalid_session))
    end
  end

  post "/flush-mailbox" do
    auth_header = Enum.find(conn.req_headers, fn {k, _} -> k == "authorization" end)

    # get session id from header
    case auth_header do
      {"authorization", "Session " <> session_id} ->
        {:ok, session} = V1.Session.lookup_session(session_id)
        config = V1.Session.get_config(session)
        messages = V1.Session.flush_mailbox(session)

        encode(conn, config, ok_payload(messages))

      _ ->
        json(conn, error_payload(:invalid_session))
    end
  end

  ## Helpers ##

  defp process_payload(conn) do
    session = conn.assigns[:session]
    config = V1.Session.get_config(session)
    {:ok, message} = V1.parse(V1.Payload, conn.body_params)
    V1.Session.send_incoming_message(session, message)
    encode(conn, config, ok_payload(:ok))
  end

  defp encode(conn, config, data) do
    data =
      case config.format do
        "json" -> Jason.encode!(data)
        "msgpack" -> Msgpax.pack!(data)
      end

    data =
      case config.compression do
        "none" -> data
        "zstd" -> :ezstd.compress(data)
      end

    mime_type =
      case config.format do
        "json" -> "application/json+#{config.format}"
        "msgpack" -> "application/msgpack+#{config.format}"
      end

    conn
    |> put_resp_content_type(mime_type)
    |> send_resp(200, data)
  end

  defp json(conn, params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(params))
  end
end
