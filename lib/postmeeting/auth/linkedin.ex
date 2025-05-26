defmodule Postmeeting.Auth.LinkedIn do
  use OAuth2.Strategy

  def client do
    OAuth2.Client.new(
      strategy: __MODULE__,
      client_id: System.get_env("LINKEDIN_CLIENT_ID"),
      client_secret: System.get_env("LINKEDIN_CLIENT_SECRET"),
      redirect_uri: System.get_env("LINKEDIN_REDIRECT_URI"),
      site: "https://api.linkedin.com",
      authorize_url: "https://www.linkedin.com/oauth/v2/authorization",
      token_url: "https://www.linkedin.com/oauth/v2/accessToken"
    )
  end

  def authorize_url! do
    OAuth2.Client.authorize_url!(client(), scope: "r_liteprofile r_emailaddress w_member_social")
  end

  def get_token!(params \\ [], headers \\ [], opts \\ []) do
    OAuth2.Client.get_token!(client(), params, headers, opts)
  end

  # Strategy callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param(:client_secret, client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  # API Access helpers

  def get_user_profile(client) do
    url =
      "/v2/me?projection=(id,localizedFirstName,localizedLastName,profilePicture(displayImage~digitalmediaAsset:playableStreams),emailAddress)"

    {:ok, %OAuth2.Response{body: user}} =
      OAuth2.Client.get(client, url)

    %{
      first_name: user["localizedFirstName"],
      last_name: user["localizedLastName"],
      email: get_user_email(client),
      linkedin_id: user["id"]
    }
  end

  def get_user_email(client) do
    {:ok, %OAuth2.Response{body: %{"elements" => [%{"handle~" => %{"emailAddress" => email}}]}}} =
      OAuth2.Client.get(client, "/v2/emailAddress?q=members&projection=(elements*(handle~))")

    email
  end

  def post_share(account, text) do
    url = "https://api.linkedin.com/v2/ugcPosts"

    headers = [
      {"Authorization", "Bearer #{account.access_token}"},
      {"Content-Type", "application/json"},
      {"X-Restli-Protocol-Version", "2.0.0"}
    ]

    body = %{
      "author" => "urn:li:person:#{account.linkedin_id}",
      "lifecycleState" => "PUBLISHED",
      "specificContent" => %{
        "com.linkedin.ugc.ShareContent" => %{
          "shareCommentary" => %{
            "text" => text
          },
          "shareMediaCategory" => "NONE"
        }
      },
      "visibility" => %{
        "com.linkedin.ugc.MemberNetworkVisibility" => "PUBLIC"
      }
    }

    case Tesla.post(url, Jason.encode!(body), headers: headers) do
      {:ok, %{status: 201, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{body: body}} ->
        {:error, Jason.decode!(body)}

      {:error, error} ->
        {:error, error}
    end
  end
end
