defmodule Openapi.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :openapi
  plug Openapi.TestRouter
end
