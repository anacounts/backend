defmodule Anacounts.Transfers.MoneyTransfer do
  @moduledoc """
  Entity representing money transfers. This includes both payments,
  incomes and reimbursements.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Anacounts.Accounts
  alias Anacounts.Accounts.Balance
  alias Anacounts.Transfers

  # the types
  @transfer_types [:payment, :income, :reimbursement]

  @type id :: integer()
  @type t :: %__MODULE__{
          id: id(),
          amount: Money.t(),
          type: :payment | :income | :reimbursement,
          book: Accounts.Book.t(),
          tenant: Accounts.BookMember.t(),
          balance_params: Balance.TransferParams.t(),
          peers: Transfers.Peer.t()
        }

  schema "transfers_money_transfers" do
    field :label, :string
    field :amount, Money.Ecto.Composite.Type
    field :type, Ecto.Enum, values: @transfer_types
    field :date, :utc_datetime

    belongs_to :book, Accounts.Book
    belongs_to :tenant, Accounts.BookMember

    # balance
    field :balance_params, Balance.TransferParams

    has_many :peers, Transfers.Peer,
      foreign_key: :transfer_id,
      on_replace: :delete_if_exists

    timestamps()
  end

  ## Changesets

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:label, :amount, :type, :date, :book_id, :tenant_id, :balance_params])
    |> validate_label()
    |> validate_required(:amount)
    |> validate_type()
    |> validate_book_id()
    |> validate_tenant_id()
    |> validate_balance_params()
    |> cast_assoc(:peers, with: &Transfers.Peer.create_money_transfer_changeset/2)
  end

  def update_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:label, :amount, :type, :date, :tenant_id, :balance_params])
    |> validate_label()
    |> validate_required(:amount)
    |> validate_type()
    |> validate_tenant_id()
    |> validate_balance_params()
    |> cast_assoc(:peers, with: &Transfers.Peer.update_money_transfer_changeset/2)
  end

  defp validate_label(changeset) do
    changeset
    |> validate_required(:label)
    |> validate_length(:label, min: 1, max: 255)
  end

  defp validate_type(changeset) do
    changeset
    |> validate_inclusion(:type, @transfer_types)
  end

  defp validate_book_id(changeset) do
    changeset
    |> validate_required(:book_id)
    |> foreign_key_constraint(:book_id)
  end

  defp validate_tenant_id(changeset) do
    changeset
    |> validate_required(:tenant_id)
    |> foreign_key_constraint(:tenant_id)
  end

  defp validate_balance_params(changeset) do
    changeset
    |> Balance.TransferParams.validate_changeset(:balance_params)
  end

  ## Queries

  def base_query do
    from __MODULE__, as: :money_transfer
  end

  def where_book_id(query, book_id) do
    from [money_transfer: money_transfer] in query,
      where: money_transfer.book_id == ^book_id
  end

  ## Struct functions

  @spec amount(t()) :: Money.t()
  def amount(transfer)
  def amount(%{type: :payment, amount: amount}), do: amount
  def amount(%{type: _income_or_reimbursement, amount: amount}), do: Money.neg(amount)
end
