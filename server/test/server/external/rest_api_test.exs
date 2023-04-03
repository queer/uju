defmodule Server.External.RestAPITest do
  use ExUnit.Case, async: true
  use Plug.Test

  describe "basic functionality" do
    test "it works" do
      # Start the session
      conn = conn(:post, "/api/v1/start-session", %{compression: "none", format: "json"})
      conn = Server.External.RestAPI.call(conn, %{})
      assert conn.status == 200

      res = Jason.decode!(conn.resp_body)
      assert res["status"] == "ok"
      assert res["session_id"]

      session_id = res["session_id"]

      # Assert the HELLO interaction
      assert %{"status" => "ok", "messages" => messages} = fetch_messages(session_id)
      assert [%{"opcode" => "HELLO"}] = messages

      # Authenticate with the server
      res =
        send_payload(session_id, %{
          opcode: "AUTHENTICATE",
          payload: %{auth: "a", config: %{format: "json", compression: "none"}}
        })

      assert res["status"] == "ok"

      # Assert the SERVER_MESSAGE with code 0
      assert %{"status" => "ok", "messages" => messages} = fetch_messages(session_id)

      assert [
               %{
                 "opcode" => "SERVER_MESSAGE",
                 "payload" => %{"code" => 0, "layer" => "protocol", "message" => "auth success"}
               }
             ] = messages

      # Send a message
      res =
        send_payload(session_id, %{
          opcode: "SEND",
          payload: %{
            method: "immediate",
            data: "test",
            config: %{nonce: "asdf", await_reply: false}
          }
        })

      assert res["status"] == "ok"

      # Assert the RECEIVE interaction
      assert %{"status" => "ok", "messages" => messages} = fetch_messages(session_id)

      assert [
               %{
                 "opcode" => "RECEIVE",
                 "payload" => %{
                   "data" => "test",
                   "nonce" => "asdf"
                 }
               }
             ] = messages
    end
  end

  defp init_session do
    # Start the session
    conn = conn(:post, "/api/v1/start-session", %{compression: "none", format: "json"})
    conn = Server.External.RestAPI.call(conn, %{})
    assert conn.status == 200

    res = Jason.decode!(conn.resp_body)
    assert res["status"] == "ok"
    assert res["session_id"]

    session_id = res["session_id"]

    # Assert the HELLO interaction
    assert %{"status" => "ok", "messages" => messages} = fetch_messages(session_id)
    assert [%{"opcode" => "HELLO"}] = messages

    # Authenticate with the server
    conn =
      conn(:post, "/api/v1", %{
        opcode: "AUTHENTICATE",
        payload: %{auth: "a", config: %{format: "json", compression: "none"}}
      })
      |> auth(session_id)

    conn = Server.External.RestAPI.call(conn, %{})
    res = Jason.decode!(conn.resp_body)
    assert res["status"] == "ok"

    # Assert the SERVER_MESSAGE with code 0
    assert %{"status" => "ok", "messages" => messages} = fetch_messages(session_id)

    assert [
             %{
               "opcode" => "SERVER_MESSAGE",
               "payload" => %{"code" => 0, "layer" => "protocol", "message" => "auth success"}
             }
           ] = messages
  end

  defp send_payload(session, payload) do
    conn =
      conn(:post, "/api/v1", payload)
      |> auth(session)

    conn = Server.External.RestAPI.call(conn, %{})
    res = Jason.decode!(conn.resp_body)
    assert res["status"] == "ok"
    res
  end

  defp fetch_messages(session) do
    conn = conn(:post, "/api/v1/flush-mailbox") |> auth(session)
    conn = Server.External.RestAPI.call(conn, %{})
    Jason.decode!(conn.resp_body)
  end

  defp auth(conn, session) do
    conn
    |> put_req_header("authorization", "Session #{session}")
  end
end
