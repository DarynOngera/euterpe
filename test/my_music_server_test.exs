defmodule MyMusicServerTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn
  alias MyMusicServer.Router

  @opts Router.init([])

  test "GET / returns server status" do
    conn = conn(:get, "/") |> Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "Server is running"
  end

  test "GET /health returns OK" do
    conn = conn(:get, "/health") |> Router.call(@opts)
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body)["status"] == "OK"
  end

  test "POST /jobs accepts a job" do
    conn =
      conn(:post, "/jobs", Jason.encode!(%{"payload" => %{"task" => "test"}}))
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 202
    body = Jason.decode!(conn.resp_body)
    assert body["message"] == "Job accepted"
    assert is_integer(body["job_id"])
  end

  test "GET /jobs returns list" do
    conn = conn(:get, "/jobs") |> Router.call(@opts)
    assert conn.status == 200
    assert is_list(Jason.decode!(conn.resp_body))
  end

  test "GET /songs returns a list" do
    conn = conn(:get, "/songs") |> Router.call(@opts)
    assert conn.status == 200
    assert is_list(Jason.decode!(conn.resp_body))
  end

  test "GET /playlists returns a list" do
    conn = conn(:get, "/playlists") |> Router.call(@opts)
    assert conn.status == 200
    assert is_list(Jason.decode!(conn.resp_body))
  end
end
