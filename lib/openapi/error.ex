defmodule Openapi.Error do
  @moduledoc """
  Base error for OpenAPI validation and routing failures.
  """

  defexception [:message, :details]

  @impl true
  def exception(opts) when is_binary(opts) do
    %__MODULE__{message: opts}
  end

  def exception(opts) when is_list(opts) do
    message =
      """
      #{Keyword.get(opts, :message, "OpenAPI error")}

      Details:
      #{inspect(Keyword.get(opts, :details, %{}), pretty: true)}
      """

    %__MODULE__{message: message}
  end
end
