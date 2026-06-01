defmodule MyMusicServer.EventBus do
  @moduledoc """
  Pub/sub event bus using the built-in Registry.

  Topics:
    - :jobs       — all job lifecycle events
    - :system    — system health events
    - {:job, id} — events for a specific job
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :duplicate,
      name: __MODULE__,
      partitions: System.schedulers_online()
    )
  end

  def subscribe(topic) when is_atom(topic) or is_tuple(topic) do
    Registry.register(__MODULE__, topic, [])
    :ok
  end

  def unsubscribe(topic) when is_atom(topic) or is_tuple(topic) do
    Registry.unregister(__MODULE__, topic)
    :ok
  end

  def publish(topic, payload) when is_atom(topic) or is_tuple(topic) do
    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:bus_event, payload})
      end
    end)

    :ok
  end
end
