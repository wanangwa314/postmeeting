defmodule Postmeeting.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Postmeeting.Repo

  alias Postmeeting.Accounts.{
    User,
    UserToken,
    UserNotifier,
    GoogleAccount,
    LinkedinAccount,
    FacebookAccount
  }

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Returns a list of all users.
  """
  def list_users do
    Repo.all(User)
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Google Account Management

  def list_google_accounts(user) do
    Repo.all(
      from(g in GoogleAccount,
        where: g.user_id == ^user.id and g.calendar_sync_enabled == true
      )
    )
  end

  def list_all_google_accounts(user) do
    Repo.all(from(g in GoogleAccount, where: g.user_id == ^user.id))
  end

  def get_google_account_by_user(user) do
    # First try to get the primary account with calendar sync enabled
    primary_account =
      Repo.one(
        from(g in GoogleAccount,
          where:
            g.user_id == ^user.id and g.calendar_sync_enabled == true and g.is_primary == true
        )
      )

    case primary_account do
      nil ->
        # If no primary account found, get any calendar sync enabled account
        Repo.one(
          from(g in GoogleAccount,
            where: g.user_id == ^user.id and g.calendar_sync_enabled == true,
            limit: 1
          )
        )

      account ->
        account
    end
  end

  def get_google_account(user, id) do
    Repo.get_by(GoogleAccount, user_id: user.id, id: id)
  end

  def disconnect_google_account(user, account_id) do
    case get_google_account(user, account_id) do
      nil ->
        {:error, :not_found}

      account ->
        if account.is_primary do
          # Get all non-primary accounts
          other_accounts =
            Repo.all(
              from(g in GoogleAccount,
                where: g.user_id == ^user.id and g.id != ^account.id
              )
            )

          # If there are other accounts, make the first one primary
          case other_accounts do
            [next_primary | _] ->
              {:ok, _} = update_google_account(next_primary, %{is_primary: true})

            [] ->
              :ok
          end
        end

        Repo.delete(account)
    end
  end

  def update_google_account(%GoogleAccount{} = google_account, attrs) do
    google_account
    |> GoogleAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user with a primary Google account or logs in an existing user.
  """
  def create_user_with_google(user_params, auth) do
    case get_user_by_email(user_params.email) do
      # User exists, ensure they have a Google account
      %User{} = user ->
        case get_primary_google_account(user) do
          nil ->
            # Add Google account as primary
            create_primary_google_account(user, auth)
            {:ok, user}

          _google_account ->
            # User already has a primary Google account
            {:ok, user}
        end

      nil ->
        # Create new user and primary Google account
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, user_params))
        |> Ecto.Multi.insert(:google_account, fn %{user: user} ->
          GoogleAccount.changeset(%GoogleAccount{}, %{
            user_id: user.id,
            email: auth.info.email,
            access_token: auth.credentials.token,
            refresh_token: auth.credentials.refresh_token,
            expires_at:
              auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
            scope: auth.credentials.scopes,
            is_primary: true,
            calendar_sync_enabled: true
          })
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{user: user}} -> {:ok, user}
          {:error, _, changeset, _} -> {:error, changeset}
        end
    end
  end

  @doc """
  Gets the primary Google account for a user.
  """
  def get_primary_google_account(user) do
    Repo.one(from(g in GoogleAccount, where: g.user_id == ^user.id and g.is_primary == true))
  end

  @doc """
  Creates a primary Google account for an existing user.
  """
  def create_primary_google_account(user, auth) do
    %GoogleAccount{}
    |> GoogleAccount.changeset(%{
      user_id: user.id,
      email: auth.info.email,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
      scope: Enum.join(auth.credentials.scopes, " "),
      is_primary: true,
      calendar_sync_enabled: true
    })
    |> Repo.insert()
  end

  @doc """
  Adds an additional Google account for calendar sync.
  """
  def add_google_calendar_account(user, auth) do
    case Repo.get_by(GoogleAccount, email: auth.info.email) do
      nil ->
        %GoogleAccount{}
        |> GoogleAccount.changeset(%{
          user_id: user.id,
          email: auth.info.email,
          access_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          expires_at:
            auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
          scope: Enum.join(auth.credentials.scopes, " "),
          is_primary: false,
          calendar_sync_enabled: true
        })
        |> Repo.insert()

      _account ->
        {:error, :already_connected}
    end
  end

  @doc """
  Adds a LinkedIn account for posting.
  """
  def add_linkedin_account(user, auth) do
    case Repo.get_by(LinkedinAccount, email: auth.info.email) do
      nil ->
        %LinkedinAccount{}
        |> LinkedinAccount.changeset(%{
          user_id: user.id,
          email: auth.info.email,
          access_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          expires_at:
            auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
          scope: Enum.join(auth.credentials.scopes, " ")
        })
        |> Repo.insert()

      _account ->
        {:error, :already_connected}
    end
  end

  @doc """
  Adds a Facebook account for posting.
  """
  def add_facebook_account(user, auth) do
    case Repo.get_by(FacebookAccount, email: auth.info.email) do
      nil ->
        %FacebookAccount{}
        |> FacebookAccount.changeset(%{
          user_id: user.id,
          email: auth.info.email,
          access_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          expires_at:
            auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
          scope: Enum.join(auth.credentials.scopes, " ")
        })
        |> Repo.insert()

      _account ->
        {:error, :already_connected}
    end
  end

  def list_google_accounts_expiring_soon(threshold_datetime) do
    from(g in GoogleAccount,
      where:
        not is_nil(g.refresh_token) and
          (is_nil(g.expires_at) or g.expires_at <= ^threshold_datetime)
    )
    |> Repo.all()
  end

  def create_or_update_google_account(user, auth) do
    google_email = auth.info.email
    existing_account = Repo.get_by(GoogleAccount, user_id: user.id, email: google_email)

    attrs = %{
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      # Ensure expires_at is handled correctly if it might be nil from auth
      expires_at: calculate_expiry(Map.get(auth.credentials, :expires_at)),
      scope: auth.credentials.scopes |> Enum.join(" "),
      email: google_email,
      name: auth.info.name || auth.info.nickname,
      user_id: user.id
    }

    case existing_account do
      nil ->
        %GoogleAccount{}
        |> GoogleAccount.changeset(attrs)
        |> Repo.insert()

      account ->
        # When updating, we might not always get a new refresh token
        # Only update refresh_token if a new one is provided
        update_attrs =
          if is_nil(attrs.refresh_token) do
            Map.drop(attrs, [:refresh_token])
          else
            attrs
          end

        account
        |> GoogleAccount.changeset(update_attrs)
        |> Repo.update()
    end
  end

  defp calculate_expiry(nil), do: nil

  defp calculate_expiry(expires_at) when is_integer(expires_at) do
    DateTime.from_unix!(expires_at)
  end

  # Helper functions
  defp get_token_expiry(nil), do: nil

  defp get_token_expiry(expires_at) when is_integer(expires_at) do
    DateTime.from_unix!(expires_at)
  end

  defp get_token_expiry(expires_at), do: expires_at

  ## LinkedIn Account Management

  def list_linkedin_accounts(user) do
    Repo.all(from(l in LinkedinAccount, where: l.user_id == ^user.id))
  end

  def get_linkedin_account(user, id) do
    Repo.get_by(LinkedinAccount, user_id: user.id, id: id)
  end

  def get_linkedin_account_by_user(user) do
    Repo.one(from(l in LinkedinAccount, where: l.user_id == ^user.id))
  end

  def disconnect_linkedin_account(user, account_id) do
    case get_linkedin_account(user, account_id) do
      nil -> {:error, :not_found}
      account -> Repo.delete(account)
    end
  end

  def create_linkedin_account(user, auth) do
    case get_linkedin_account_by_user(user) do
      nil ->
        %LinkedinAccount{}
        |> LinkedinAccount.changeset(%{
          access_token: auth.credentials.token,
          linkedin_id: auth.uid,
          name: auth.info.name || "#{auth.info.first_name} #{auth.info.last_name}",
          email: auth.info.email,
          user_id: user.id
        })
        |> Repo.insert()

      _existing ->
        {:error, :already_connected}
    end
  end

  ## Facebook Account Management

  def list_facebook_accounts(user) do
    Repo.all(from(g in FacebookAccount, where: g.user_id == ^user.id))
  end

  def get_facebook_account(user, id) do
    Repo.get_by(FacebookAccount, user_id: user.id, id: id)
  end

  def get_facebook_account_by_facebook_id(facebook_id) do
    Repo.get_by(FacebookAccount, facebook_id: facebook_id)
  end

  def disconnect_facebook_account(user, account_id) do
    case get_facebook_account(user, account_id) do
      nil -> {:error, :not_found}
      account -> Repo.delete(account)
    end
  end

  def create_facebook_account(user, auth) do
    case get_facebook_account_by_user(user) do
      nil ->
        attrs = %{
          access_token: auth.credentials.token,
          expires_at: get_token_expiry(auth.credentials.expires_at),
          facebook_id: auth.uid,
          name: auth.info.name,
          email: auth.info.email,
          user_id: user.id
        }

        %FacebookAccount{}
        |> FacebookAccount.changeset(attrs)
        |> Repo.insert()

      _account ->
        {:error, :already_connected}
    end
  end

  def get_facebook_account_by_user(user) do
    Repo.one(from(f in FacebookAccount, where: f.user_id == ^user.id))
  end
end
