defmodule Anacounts.Accounts.Book do
  @moduledoc """
  The entity grouping users and transfers.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Anacounts.Accounts
  alias Anacounts.Accounts.Balance
  alias Anacounts.Auth

  @type id :: integer()
  @type t :: %__MODULE__{
          id: id(),
          name: String.t(),
          deleted_at: NaiveDateTime.t(),
          members: [Accounts.BookMember.t()],
          users: [Auth.User.t()],
          default_balance_params: Balance.TransferParams.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "accounts_books" do
    field :name, :string
    field :deleted_at, :naive_datetime

    # user relation
    has_many :members, Accounts.BookMember
    many_to_many :users, Auth.User, join_through: Accounts.BookMember

    # balance
    field :default_balance_params, Balance.TransferParams

    timestamps()
  end

  ## Changeset

  @doc """
  A book changeset for creation.
  The user given will be considered the first member and creator of the book.
  """
  def create_changeset(user, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :default_balance_params])
    |> validate_name()
    |> validate_default_balance_params()
    |> put_creator(user)
  end

  def update_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :default_balance_params])
    |> validate_name()
    |> validate_default_balance_params()
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required(:name)
    |> validate_length(:name, max: 255)
  end

  defp validate_default_balance_params(changeset) do
    changeset
    |> validate_required(:default_balance_params)
    |> Balance.TransferParams.validate_changeset(:default_balance_params)
  end

  defp put_creator(changeset, creator) do
    changeset
    |> put_change(:members, [
      %{
        user: creator,
        role: :creator
      }
    ])
  end

  def delete_changeset(book) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(book, deleted_at: now)
  end

  ## Query

  @spec base_query :: Ecto.Query.t()
  def base_query do
    from b in __MODULE__, where: is_nil(b.deleted_at)
  end

  @spec user_query(Auth.User.t()) :: Ecto.Query.t()
  def user_query(user) do
    from b in base_query(),
      join: u in assoc(b, :users),
      on: u.id == ^user.id
  end
end
