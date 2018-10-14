class Api::TransactionsController < ApplicationController
  before_action :require_log_in

  def create
    @transaction = current_user.transactions.build(transaction_params)
    unless @transaction.save
      render json: @transaction.errors.full_messages, status: 422
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:symbol, :shares)
  end
end
