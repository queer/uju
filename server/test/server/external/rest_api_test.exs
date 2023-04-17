defmodule Server.External.RestAPITest do
  use ExUnit.Case, async: true
  use Plug.Test

  describe "basic functionality" do
    test "a session can be created and send and receive messages" do
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

      __test_is_too_quick!()

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

    test "session configuration works" do
      session_id = init_session()

      res =
        send_payload(session_id, %{
          opcode: "CONFIGURE",
          payload: %{scope: "session", config: %{format: "msgpack", compression: "none"}}
        })

      assert res["status"] == "ok"

      __test_is_too_quick!()

      assert %{"messages" => messages, "status" => "ok"} = fetch_messages(session_id, :msgpack)
      assert [message | _] = messages

      assert message["opcode"] == "SERVER_MESSAGE"

      assert %{"code" => 2, "message" => "config success", "layer" => "protocol"} =
               message["payload"]
    end

    test "it returns useful error messages when failing to parse a payload" do
      conn = conn(:post, "/api/v1/start-session", %{format: "json"})
      conn = Server.External.RestAPI.call(conn, %{})
      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)

      assert %{
               "opcode" => "SERVER_MESSAGE",
               "payload" => %{
                 "code" => 3,
                 "layer" => "protocol",
                 "message" => "parse fail",
                 "extra" => %{
                   "input" => %{"format" => "json"},
                   "schema" => %{
                     "compression" => ["any", ["none", "zstd"]],
                     "format" => ["any", ["json", "msgpack"]],
                     "metadata" => ["optional", "any"]
                   }
                 }
               }
             } = body
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

    session_id
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

  defp fetch_messages(session, format \\ :json) do
    conn = conn(:post, "/api/v1/flush-mailbox") |> auth(session)
    conn = Server.External.RestAPI.call(conn, %{})

    case format do
      :json -> Jason.decode!(conn.resp_body)
      :msgpack -> Msgpax.unpack!(conn.resp_body)
    end
  end

  defp auth(conn, session) do
    conn
    |> put_req_header("authorization", "Session #{session}")
  end

  defp __test_is_too_quick! do
    :timer.sleep(10)
  end
end
