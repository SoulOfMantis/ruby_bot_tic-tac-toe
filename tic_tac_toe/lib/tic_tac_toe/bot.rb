module TicTacToe
  class Bot
    # Функция "Входа": берет данные из сообщения и возвращает игрока
    def self.handle_user(message)
      {
        id: message.chat.id,
        name: message.from.first_name,
        username: message.from.username
      }
    end
    def self.game_keyboard(board)
      buttons = (0..2).map do |row|
        (0..2).map do |col|
          display_text = case board[row][col]
                         when 'X' then '❌'
                         when 'O' then '⭕'
                         else ' '
                         end
          
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: display_text, 
            callback_data: "cell_#{row}_#{col}"
          )
        end
      end
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    end
  end
end