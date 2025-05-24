defmodule Postmeeting.Repo do
  use Ecto.Repo,
    otp_app: :postmeeting,
    adapter: Ecto.Adapters.Postgres
end
