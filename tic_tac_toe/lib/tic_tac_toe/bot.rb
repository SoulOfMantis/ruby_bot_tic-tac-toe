require 'telegram/bot'

module TicTacToe
  class Bot
    def initialize(token)
      @token = token
      @games = {} 
    end

    def run
      Telegram::Bot::Client.run(@token) do |bot|
        puts "Бот успешно запущен"
        bot.listen do |rq|
          case rq
          when Telegram::Bot::Types::Message
            handle_start(bot, rq) if rq.text&.include?('/start')
          when Telegram::Bot::Types::CallbackQuery
            handle_move(bot, rq)
          end
        end
      end
    end

    private

    def handle_start(bot, rq)
      chat_id = rq.chat.id
      
      game = TicTacToe::GameState.new(rq.from.id)
      game.chat_id = chat_id 
      
      msg = bot.api.send_message(
        chat_id: chat_id,
        text: "Игра началась! ❌ ходит первым.",
        reply_markup: render_keyboard(game.board)
      )

      game.message_id = msg.message_id
      @games[chat_id] = game
    end

    def handle_move(bot, rq)
      chat_id = rq.message.chat.id
      game = @games[chat_id]
      return unless game

      data = rq.data.split('_')
      row, col = data[1].to_i, data[2].to_i

      if game.can_move?(rq.from.id, row, col)
        game.make_move(row, col)
        
        bot.api.edit_message_reply_markup(
          chat_id: game.chat_id,
          message_id: game.message_id,
          reply_markup: render_keyboard(game.board)
        )

        check_winner(bot, game)
      end
      
      bot.api.answer_callback_query(callback_query_id: rq.id)
    end

    def check_winner(bot, game)
      if game.winner || game.draw?
        text = game.winner ? "Победил #{game.winner == 'X' ? '❌' : '⭕'}!" : "Ничья! 🤝"
        bot.api.send_message(chat_id: game.chat_id, text: text)
        @games.delete(game.chat_id)
      else
        game.switch_player
      end
    end

    def render_keyboard(board)
      kb = board.each_with_index.map do |row, r_idx|
        row.each_with_index.map do |cell, c_idx|
          Telegram::Bot::Types::InlineKeyboardButton.new(text: cell || " ", callback_data: "move_#{r_idx}_#{c_idx}")
        end
      end
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end
  end
end