defmodule Openapi.TestRouter do
  use Phoenix.Router
  use Openapi.Phoenix

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/" do
    pipe_through(:api)

    openapi("test/resources/simple.yaml", handler: Openapi.TestHandler)
    swagger_docs("/api-docs")
    swagger_docs("/")
  end
end
