defmodule Server.External.RestAPI do
  use Plug.Router
  alias Server.Protocol.V1

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    body_reader: {__MODULE__.CacheBodyReader, :read_body, []},
    json_decoder: Jason
  )

  post "/api/v1/start-session" do
    config = V1.parse(V1.SessionConfig, conn.body_params)
    {:ok, session_id} = V1.Machine.init_session(config)
    json(conn, %{status: :ok, session_id: session_id})
  end

  post "/api/v1" do
    auth_header = Enum.find(conn.req_headers, fn {k, _} -> k == "authorization" end)

    case auth_header do
      {"authorization", "Session " <> session_id} ->
        {:ok, session} = V1.Session.lookup_session(session_id)

        conn
        |> assign(:session, session)
        |> assign(:session_id, session_id)
        |> process_payload()

      _ ->
        json(conn, %{status: :error, error: :invalid_session})
    end
  end

  post "/api/v1/flush-mailbox" do
    auth_header = Enum.find(conn.req_headers, fn {k, _} -> k == "authorization" end)

    # get session id from header
    case auth_header do
      {"authorization", "Session " <> session_id} ->
        {:ok, session} = V1.Session.lookup_session(session_id)
        config = V1.Session.get_config(session)
        messages = V1.Session.flush_mailbox(session)

        encode(conn, config, %{status: :ok, messages: messages})

      _ ->
        json(conn, %{status: :error, error: :invalid_session})
    end
  end

  def process_payload(conn) do
    session = conn.assigns[:session]
    config = V1.Session.get_config(session)
    payload_valid = conn.body_params["opcode"] in ["AUTHENTICATE", "SEND", "PING", "CONFIGURE"]

    if payload_valid do
      message = V1.parse(V1.Payload, conn.body_params)

      send(conn.assigns[:session], {:in, message})

      encode(conn, config, %{status: :ok})
    else
      encode(conn, config, %{status: :error, error: :invalid_payload})
    end
  end

  def encode(conn, config, data) do
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

  defmodule CacheBodyReader do
    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
