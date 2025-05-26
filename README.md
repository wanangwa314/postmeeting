# Postmeeting

## Setup

### Environment Variables

Load the environment variables before starting the server

```bash
# Google OAuth
export GOOGLE_CLIENT_ID=your_google_client_id
export GOOGLE_CLIENT_SECRET=your_google_client_secret

# Facebook OAuth
export FACEBOOK_CLIENT_ID=your_facebook_app_id
export FACEBOOK_CLIENT_SECRET=your_facebook_app_secret

# LinkedIn OAuth
export LINKEDIN_CLIENT_ID=your_linkedin_client_id
export LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
export LINKEDIN_REDIRECT_URI=http://localhost:4000/auth/linkedin/callback

# API Keys
export RECALL_API_KEY=your_recall_api_key
export GEMINI_API_KEY=your_gemini_api_key
```


### Starting the Server

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
