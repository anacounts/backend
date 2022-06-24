defmodule Anacounts.TransfersFixtures do
  @moduledoc """
  Fixtures for the `Transfer` context
  """

  alias Anacounts.Transfers

  def valid_money_transfer_amount, do: Money.new(179_99, :EUR)
  def valid_money_transfer_date, do: ~U[2022-06-23 14:02:51Z]
  def valid_money_transfer_type, do: :payment

  def valid_money_transfer_attributes(attrs \\ %{}) do
    %{
      amount: valid_money_transfer_amount(),
      date: valid_money_transfer_date(),
      type: valid_money_transfer_type(),
      peers: []
    }
    |> Map.merge(attrs)
  end

  def money_transfer_fixture(book, user, attrs \\ %{}) do
    valid_attrs = valid_money_transfer_attributes(attrs)
    {:ok, transfer} = Transfers.create_transfer(book.id, user.id, valid_attrs)
    transfer
  end

  def setup_money_transfer_fixture(%{book: book, user: user} = context) do
    Map.put(context, :money_transfer, money_transfer_fixture(book, user))
  end
end