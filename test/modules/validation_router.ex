defmodule Openapi.ValidationRouter do
  use Phoenix.Router
  use Openapi.Phoenix

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Openapi.ValidatorPlug)
  end

  scope "/" do
    pipe_through(:api)

    openapi("test/resources/validation.yaml", handler: Openapi.ValidationHandler)
  end
end
