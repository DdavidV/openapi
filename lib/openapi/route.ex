defmodule Openapi.Route do
  defstruct [
    :method,
    :path,
    :handler,
    :operation_id
  ]
end
