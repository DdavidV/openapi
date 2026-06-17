defmodule Openapi.Route do
  @moduledoc false
  defstruct [
    :method,
    :path,
    :handler,
    :operation_id,
    :schemas
  ]
end
