defmodule Postmeeting.Auth.Facebook do
  @graph_api_version "v19.0"
  @graph_api_url "https://graph.facebook.com/#{@graph_api_version}"

  def post_to_feed(account, message) do
    url = "#{@graph_api_url}/me/feed"

    params = [
      access_token: account.access_token,
      message: message
    ]

    case Tesla.post(url, "", query: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{body: body}} ->
        {:error, Jason.decode!(body)}

      {:error, error} ->
        {:error, error}
    end
  end
end
