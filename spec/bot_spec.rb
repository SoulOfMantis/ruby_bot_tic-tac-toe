require 'telegram/bot'
require_relative '../tic_tac_toe/lib/tic_tac_toe/bot'

RSpec.describe TicTacToe::Bot do
  describe '.handle_user' do
    it 'правильно извлекает данные пользователя через мокап' do
      message = double('Telegram::Bot::Types::Message')
      user = double('User', first_name: 'Mawa', username: 'mawa_dev')
      chat = double('Chat', id: 12345)

      allow(message).to receive(:from).and_return(user)
      allow(message).to receive(:chat).and_return(chat)

      result = TicTacToe::Bot.handle_user(message)

      expect(result[:name]).to eq('Mawa')
      expect(result[:id]).to eq(12345)
    end
  end
end
