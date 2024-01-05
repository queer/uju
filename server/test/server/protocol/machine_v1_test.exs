defmodule Server.Protocol.V1.MachineTest do
  use ExUnit.Case
  alias Server.Protocol.V1
  doctest V1.Machine

  describe "init_session/1" do
    test "it inits a session" do
      {:ok, session, session_id} =
        V1.Machine.init_session(%V1.SessionConfig{
          format: "json",
          compression: "none",
          metadata: %{}
        })

      assert session_id
      assert Process.alive?(session)
      Process.exit(session, :normal)
    end
  end

  describe "process_message/2" do
    setup do
      {:ok, session, session_id} =
        V1.Machine.init_session(%V1.SessionConfig{
          format: "json",
          compression: "none",
          metadata: %{}
        })

      assert session_id
      assert Process.alive?(session)

      %{session: session}
    end

    test "handles AuthenticatePayload", %{session: session} do
      V1.Machine.process_message(session, %V1.Payload{
        payload: %V1.AuthenticatePayload{}
      })

      assert V1.Session.authenticated?(session)
    end

    test "handles SendPayload", %{session: session} do
      V1.Machine.process_message(session, %V1.Payload{
        payload: %V1.AuthenticatePayload{}
      })

      V1.Session.flush_mailbox(session)

      V1.Machine.process_message(session, %V1.Payload{
        payload: %V1.SendPayload{
          method: "immediate",
          data: "hello!",
          config: %V1.SendImmediateConfig{nonce: "asdf"},
          query: %V1.MetadataQuery{
            _debug: %{},
            filter: [],
            select: nil
          }
        }
      })

      mailbox = V1.Session.flush_mailbox(session)

      assert match?(
               [%V1.Payload{payload: %V1.ReceivePayload{data: "hello!", nonce: "asdf"}}],
               mailbox
             )
    end

    test "handles PingPayload", %{session: session} do
      assert V1.Machine.process_message(session, %V1.Payload{
               payload: %V1.PingPayload{}
             })
    end

    test "handles ConfigurePayload", %{session: session} do
      assert V1.Machine.process_message(session, %V1.Payload{
               payload: %V1.ConfigurePayload{
                 scope: "session",
                 config: %V1.SessionConfig{
                   format: "json",
                   compression: "zstd",
                   metadata: %{}
                 }
               }
             })

      config = V1.Session.get_config(session)
      assert match?(%V1.SessionConfig{format: "json", compression: "zstd"}, config)
    end

    test "won't send a SendPayload to a session that doesn't match", %{session: session} do
      V1.Machine.process_message(session, %V1.Payload{
        payload: %V1.AuthenticatePayload{}
      })

      V1.Session.flush_mailbox(session)

      V1.Machine.process_message(session, %V1.Payload{
        payload: %V1.SendPayload{
          method: "immediate",
          data: "hello!",
          config: %V1.SendImmediateConfig{nonce: "asdf"},
          query: %V1.MetadataQuery{
            _debug: %{},
            filter: [%{"path" => "/foo", "op" => "$eq", "value" => %{"value" => "bar"}}],
            select: nil
          }
        }
      })

      mailbox = V1.Session.flush_mailbox(session)

      refute match?(
               [%V1.Payload{payload: %V1.ReceivePayload{data: "hello!", nonce: "asdf"}}],
               mailbox
             )
    end
  end
end
