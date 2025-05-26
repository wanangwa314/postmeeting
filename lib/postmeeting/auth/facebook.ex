defmodule Postmeeting.Auth.Facebook do
  @graph_api_version "v19.0"
  @graph_api_url "https://graph.facebook.com/#{@graph_api_version}"

  @doc """
  Generate a Facebook share dialog URL for posting content.
  This approach doesn't require special permissions and works immediately.
  """
  def generate_share_url(message, link \\ "") do
    base_url = "https://www.facebook.com/sharer/sharer.php"

    # Prepare parameters for the share dialog
    params =
      %{
        # URL to share (optional)
        "u" => link,
        # Pre-filled text for the post
        "quote" => message
      }
      # Remove empty values
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> URI.encode_query()

    "#{base_url}?#{params}"
  end

  @doc """
  Generate a more advanced share URL with additional metadata.
  Useful if you want to share a link to your meeting or app with the post.
  """
  def generate_share_url_with_link(message, link, hashtag \\ nil) do
    base_url = "https://www.facebook.com/sharer/sharer.php"

    params =
      %{
        "u" => link,
        "quote" => message
      }
      |> then(fn params ->
        if hashtag && hashtag != "" do
          Map.put(params, "hashtag", hashtag)
        else
          params
        end
      end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> URI.encode_query()

    "#{base_url}?#{params}"
  end

  @doc """
  Direct API posting - kept for future use when you get Facebook app approval.
  This will only work with proper permissions after app review.
  """
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

  @doc """
  Check if the connected Facebook account has posting permissions.
  For now, this returns false since we're using share dialog approach.
  """
  def has_posting_permissions?(_account) do
    # Return false until you get Facebook app approval for posting permissions
    false
  end
end
