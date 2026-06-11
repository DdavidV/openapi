defmodule Openapi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Openapi.Cache
    ]
    opts = [strategy: :one_for_one, name: Openapi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
