defmodule Server.Protocol.V1.SessionTest do
  use ExUnit.Case
  alias Server.Protocol.V1
  doctest V1.Session

  describe "session management" do
    test "times out expired sessions" do
      {:ok, session, session_id} =
        V1.Machine.init_session(%V1.SessionConfig{
          format: "json",
          compression: "none",
          metadata: %{}
        })

      assert session_id
      assert Process.alive?(session)

      :timer.sleep(V1.Machine.heartbeat_interval() * 3)

      refute Process.alive?(session)
    end
  end
end
