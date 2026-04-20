require 'telegram/bot'
require_relative 'logic'

module TicTacToe
  class Bot
    def initialize(token)
      @token = token
      @games = {}
    end

    def run
      Telegram::Bot::Client.run(@token) do |bot|
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
      game = TicTacToe::GameState.new

      game.player_x = rq.from.id
      game.name_x = rq.from.first_name
      game.chat_id = chat_id

      msg = bot.api.send_message(
        chat_id: chat_id,
        text: "Игра началась! ❌: #{game.name_x}. Ждем хода ⭕...",
        reply_markup: render_keyboard(game.board)
      )

      game.message_id = msg.message_id
      @games[chat_id] = game
    end

    def handle_move(bot, rq)
      chat_id = rq.message.chat.id
      game = @games[chat_id]
      return unless game

      user_id = rq.from.id

      if game.player_o.nil? && user_id != game.player_x
        game.player_o = user_id
        game.name_o = rq.from.first_name
      end

      unless game.valid_turn?(user_id)
        bot.api.answer_callback_query(
          callback_query_id: rq.id,
          text: "Сейчас не ваш ход!",
          show_alert: false
        )
        return
      end

      row, col = rq.data.split('_')[1..2].map(&:to_i)

      if game.make_move(row, col)
        bot.api.edit_message_reply_markup(
          chat_id: game.chat_id,
          message_id: game.message_id,
          reply_markup: render_keyboard(game.board)
        )

        check_game_status(bot, game)
      end

      bot.api.answer_callback_query(callback_query_id: rq.id)
    end

    def check_game_status(bot, game)
      return unless game.winner

      if game.winner == 'Draw'
        text = "Игра окончена! Ничья 🤝"
      else
        win_name  = game.winner == 'X' ? game.name_x : game.name_o
        lose_name = game.winner == 'X' ? game.name_o : game.name_x
        win_icon  = game.winner == 'X' ? '❌' : '⭕'
        lose_icon = game.winner == 'X' ? '⭕' : '❌'

        text = "🎉 ИГРА ОКОНЧЕНА! 🎉\n\n" \
               "🏆 Победитель: #{win_name} (#{win_icon})\n" \
               "💀 Проигравший: #{lose_name} (#{lose_icon})"
      end

      bot.api.send_message(chat_id: game.chat_id, text: text)
      @games.delete(game.chat_id)
    end

    def render_keyboard(board)
      kb = board.each_with_index.map do |row_array, row_idx|
        row_array.each_with_index.map do |cell, col_idx|
          label = cell.nil? ? " " : cell
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: label,
            callback_data: "move_#{row_idx}_#{col_idx}"
          )
        end
      end

      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end
  end
end