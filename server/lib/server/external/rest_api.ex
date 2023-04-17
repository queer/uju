defmodule Server.External.RestAPI do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    body_reader: {__MODULE__.CacheBodyReader, :read_body, []},
    json_decoder: Jason
  )

  forward("/api/v1", to: Server.External.RestAPIV1)

  defmodule CacheBodyReader do
    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end

  defimpl Jason.Encoder, for: Tuple do
    @impl true
    def encode(tuple, opts) do
      Jason.Encode.list(Tuple.to_list(tuple), opts)
    end
  end
end
