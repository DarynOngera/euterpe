defmodule MyMusicServer.Player do
  @moduledoc """
  Simple playback state manager.
  """
  use GenServer

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{current: nil}, name: __MODULE__)
  end

  def play(song_id) do
    GenServer.call(__MODULE__, {:play, song_id})
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  def current do
    GenServer.call(__MODULE__, :current)
  end

  ## GenServer Callbacks

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:play, song_id}, _from, state) do
    {:reply, :ok, %{state | current: song_id}}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    {:reply, :ok, %{state | current: nil}}
  end

  @impl true
  def handle_call(:current, _from, state) do
    {:reply, state.current, state}
  end
end
