require 'telegram/bot'
require_relative 'logic'

module TicTacToe
  class Bot
    def initialize(token)
      @token = token
      @games = {}
      @stats = {}
    end

    def run
      Telegram::Bot::Client.run(@token) do |bot|
        bot.listen do |rq|
          user = rq.from
          case rq
          when Telegram::Bot::Types::Message
            chat_id = rq.chat.id
          when Telegram::Bot::Types::CallbackQuery
            chat_id = rq.message.chat.id
          end
          @stats[chat_id] = {} unless @stats[chat_id]
          @stats[chat_id][:general_stats] = {total_games_started: 0, total_games_completed: 0, total_draws: 0,
                                             champion: nil, last_winner: nil, last_loser: nil, waiting_for_game_start: nil} unless @stats[chat_id][:general_stats]
          case rq
          when Telegram::Bot::Types::Message
            unless rq.text.nil?
              if rq.text.include? "/start_game"
                waiting_for_game_start bot, user, chat_id
              elsif rq.text.include? '/my_stats'
                stats = @stats[chat_id][user.id]
                if stats
                  is_champion = @stats[chat_id][:general_stats][:champion] == user
                  is_last_winner = @stats[chat_id][:general_stats][:last_winner] == user
                  is_last_loser = @stats[chat_id][:general_stats][:last_loser] == user
                  text = "Начато игр: #{stats[:games_started]}, завершено игр: #{stats[:games_completed]}."
                  if stats[:games_completed] != 0
                    text += "\nПобеды: #{stats[:wins]}, поражения: #{stats[:losses]}, ничьи: #{stats[:draws]}."+
                            "\nПроцент побед = #{(Float(stats[:wins])/stats[:games_completed])*100}%." +
                            "#{is_champion ? "\nВы чемпион этой группы!" : nil}" +
                            "#{is_last_winner ? "\nВам принадлежит последняя победа в этой группе!" : nil}" +
                            "#{is_last_loser ? "\nВам принадлежит последнее поражение в этой группе.." : nil}"
                  end
                  bot.api.send_message chat_id: chat_id, text: text
                else
                  bot.api.send_message chat_id: chat_id, text: "Вы пока не участвовали в играх в этой группе!"
                end
              elsif rq.text.include? '/general_stats'
                stats = @stats[chat_id][:general_stats]
                if stats
                  bot.api.send_message chat_id: chat_id, text:
                    "Начато игр: #{stats[:total_games_started]}, завершено игр: #{stats[:total_games_completed]}." +
                      "\nСыграно вничью: #{stats[:total_draws]}." +
                      "\n#{stats[:champion] ? "@#{stats[:champion].username} -- чемпион этой группы!" : 'В этой группе пока нет чемпиона...'}" +
                      "#{stats[:last_winner] ? "\n@#{stats[:last_winner].username} -- последний, кто одержал победу в этой группе!" : nil}" +
                      "#{stats[:last_loser] ? "\n@#{stats[:last_loser].username} -- последний, кто потерпел поражение в этой группе!" : nil}"
                else
                  bot.api.send_message chat_id: chat_id, text: "В этой группе не проходило игр!"
                end
              end
            end
          when Telegram::Bot::Types::CallbackQuery
            if @games[chat_id].nil?
              if rq.data == "join"
                bot.api.answer_callback_query callback_query_id: rq.id,
                                              text: waiting_for_game_start(bot, user, chat_id)

              end
            elsif @games[chat_id].player_x == user || @games[chat_id].player_o == user
              handle_move(bot, rq)
            end
          end
        end
      end
    end

    private

    def waiting_for_game_start(bot, user, chat_id)
      return 'Вы уже в очереди!' if @stats[chat_id][:waiting_for_game_start] == user
      unless @stats[chat_id][:waiting_for_game_start]
        @stats[chat_id][:waiting_for_game_start] = user
        b = Telegram::Bot::Types::InlineKeyboardButton.new text: "Присоединиться", callback_data: "join"
        kb = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: [[b]]
        bot.api.send_message chat_id:chat_id, text: "#{user.first_name} желает начать игру!", reply_markup: kb
        return 'Добавлены в очередь!'
      end
      return 'В этом чате уже идёт игра!' if @games[chat_id]
      handle_start(bot, chat_id, @stats[chat_id][:waiting_for_game_start], user)
      @stats[chat_id].delete :waiting_for_game_start
      "Успешно присоединились к игре с #{@games[chat_id].name_x}!"
    end

    def handle_start(bot, chat_id, player_x, player_o)
      @stats[chat_id][player_x.id] = {wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0} unless @stats[chat_id][player_x.id]
      @stats[chat_id][player_o.id] = {wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0} unless @stats[chat_id][player_o.id]

      @stats[chat_id][player_x.id][:games_started]+=1
      @stats[chat_id][player_o.id][:games_started]+=1
      @stats[chat_id][:general_stats][:total_games_started] += 1

      game = TicTacToe::GameState.new player_x, player_o, chat_id

      msg = bot.api.send_message(
        chat_id: chat_id,
        text: "Игра началась! Ходит ❌: #{game.name_x}.",
        reply_markup: render_keyboard(game.board)
      )

      game.message_id = msg.message_id
      @games[chat_id] = game
    end

    def handle_move(bot, rq)
      chat_id = rq.message.chat.id
      user = rq.from
      game = @games[chat_id]
      return unless game

      unless game.valid_turn? user
        bot.api.answer_callback_query(
          callback_query_id: rq.id,
          text: "Сейчас не ваш ход!",
          show_alert: false
        )
        return
      end

      row, col = rq.data.split('_')[1..2].map(&:to_i)

      if game.make_move(row, col)
        bot.api.edit_message_text(
          chat_id: game.chat_id,
          message_id: game.message_id,
          text: "Ходит #{game.current_player == 'X' ? "❌: #{game.name_x}" : "⭕: #{game.name_o}"}!"
          )
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
      chat_id = game.chat_id

      @stats[chat_id][game.player_o.id][:games_completed] += 1
      @stats[chat_id][game.player_x.id][:games_completed] += 1
      @stats[chat_id][:general_stats][:total_games_completed] += 1
      if game.winner == 'Draw'
        text = "Игра окончена! Ничья 🤝"
        @stats[chat_id][game.player_x.id][:draws] += 1
        @stats[chat_id][game.player_o.id][:draws] += 1
        @stats[chat_id][:general_stats][:total_draws] += 1
      else

        winner  = game.winner == 'X' ? game.player_x : game.player_o
        loser  = game.winner == 'X' ? game.player_o : game.player_x
        @stats[chat_id][winner.id][:wins] += 1
        @stats[chat_id][:general_stats][:last_winner] = winner
        @stats[chat_id][loser.id][:losses] += 1
        @stats[chat_id][:general_stats][:last_loser] = loser
        @stats[chat_id][:general_stats][:champion] = winner if @stats[chat_id][:general_stats][:champion].nil? || @stats[chat_id][:general_stats][:champion] == loser
        win_icon  = game.winner == 'X' ? '❌' : '⭕'
        lose_icon = game.winner == 'X' ? '⭕' : '❌'

        text = "🎉 ИГРА ОКОНЧЕНА! 🎉\n\n" \
               "🏆 Победитель: #{winner.first_name} (#{win_icon})\n" \
               "💀 Проигравший: #{loser.first_name} (#{lose_icon})"
      end
     bot.api.send_message(chat_id: chat_id, text: text)
      @games.delete chat_id
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