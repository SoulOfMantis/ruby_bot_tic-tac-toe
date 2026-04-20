require 'telegram/bot'

module TicTacToe
  class Bot
    # Метод для создания клавиатуры
    def self.game_keyboard(board)
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

    # Основной метод запуска бота
    def self.run
      token = ENV['TELEGRAM_BOT_TOKEN']
      @games ||= {} 

      Telegram::Bot::Client.run(token) do |bot|
        bot.listen do |rq|
          case rq

          when Telegram::Bot::Types::Message
            next if rq.text.nil?

            if rq.text.include?('/start')
              chat_id = rq.chat.id
              game = TicTacToe::GameState.new(rq.from.id)
              @games[chat_id] = game # Используем @

              kb = game_keyboard(game.board)
              bot.api.send_message(
                chat_id: chat_id,
                text: "Игра началась! ❌ ходит первым.\nВторой игрок может присоединиться ⭕, сделав ход.",
                reply_markup: kb
              )
            end

          when Telegram::Bot::Types::CallbackQuery
            chat_id = rq.message.chat.id
            user_id = rq.from.id
            game = @games[chat_id] # Используем @

            unless game
              bot.api.answer_callback_query(
                callback_query_id: rq.id,
                text: "Начни игру через /start",
                show_alert: true
              )
              next
            end

            data = rq.data.split('_')
            row = data[1].to_i
            col = data[2].to_i

            game.join_second_player(user_id)

            unless game.current_player?(user_id)
              bot.api.answer_callback_query(
                callback_query_id: rq.id,
                text: "Сейчас не твой ход!",
                show_alert: true
              )
              next
            end

            unless game.cell_empty?(row, col)
              bot.api.answer_callback_query(
                callback_query_id: rq.id,
                text: "Клетка занята!",
                show_alert: true
              )
              next
            end

            game.make_move(row, col)
            new_kb = game_keyboard(game.board)

            bot.api.edit_message_reply_markup(
              chat_id: chat_id,
              message_id: rq.message.message_id,
              reply_markup: new_kb
            )

            winner = game.winner
            if winner
              bot.api.send_message(
                chat_id: chat_id,
                text: "Победил #{winner == 'X' ? '❌' : '⭕'}!"
              )
              @games.delete(chat_id)
            elsif game.draw?
              bot.api.send_message(
                chat_id: chat_id,
                text: "Ничья! 🤝"
              )
              @games.delete(chat_id)
            else
              game.switch_player
            end

            bot.api.answer_callback_query(callback_query_id: rq.id)
          end
        end
      end
    end
  end
end