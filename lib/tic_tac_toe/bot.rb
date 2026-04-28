# frozen_string_literal: true

require 'telegram/bot'
require_relative 'logic'
require 'yaml'

module TicTacToe
  class Bot
    attr_reader :api
    def initialize(token)
      @token = token
    end

    def run
      Telegram::Bot::Client.run(@token, { allowed_updates: %w[message callback_query chat_member] }) do |bot|
        load_stats
        load_games
        @games.each { |chat_id, game| restore_loaded_game bot, chat_id, game }
        bot.listen do |rq|
          case rq
          when Telegram::Bot::Types::Message
            process_message bot, rq
          when Telegram::Bot::Types::CallbackQuery
            process_callback bot, rq
          when Telegram::Bot::Types::ChatMemberLeft
            process_chat_member_leaving bot, rq
          end
        end
        update_stats
      end
    end

    private

    def restore_loaded_game(bot, chat_id, game)
      create_stats_if_missing chat_id
      check_game_status bot, game
      return unless game

      current_player = game.current_player == 'X' ? game.player_x : game.player_o
      msg = bot.api.send_message chat_id: chat_id,
                                 text: 'Похоже, произошла ошибка. Игра была восстановлена. Ходит ' \
                                 "#{game.current_player == 'X' ? '❌' : '⭕'} : " \
                                 "#{get_user_by_id(bot, chat_id, current_player).first_name}.",
                                 reply_markup: render_keyboard(game.board)
      game.message_id = msg.message_id
    end

    def process_callback(bot, callback)
      chat_id = callback.message.chat.id
      user = callback.from
      create_stats_if_missing chat_id
      if @games[chat_id].nil?
        if callback.data == 'join'
          bot.api.answer_callback_query callback_query_id: callback.id,
                                        text: waiting_for_game_start(bot, user, chat_id)
        end
      elsif @games[chat_id].contains_user_id user.id
        handle_move bot, callback
      end
    end

    def process_chat_member_leaving(bot, chat_member_left_info)
      chat_id = chat_member_left_info.chat.id
      user = chat_member_left_info.user
      game_in_chat = @games[chat_id]
      return unless user.id == @stats[chat_id][:champion] || game_in_chat.contains_user_id(user.id)

      if user.id == @stats[chat_id][:champion]
        bot.api.send_message chat_id: chat_id, text: "Чемпион @#{user.username} отказался от титула и покинул группу."
        @stats[chat_id][:champion] = nil
      end
      @stats[chat_id][:waiting_for_game_start] = nil if @stats[chat_id][:waiting_for_game_start] == user.id

      return unless game_in_chat.contains_user_id user.id

      bot.api.send_message chat_id: chat_id, text: "Игрок @#{user.username} покинул группу, признав поражение."
      case user.id
      when game_in_chat.player_o
        game_in_chat.winner = game_in_chat.player_x
      when game_in_chat.player_x
        game_in_chat.winner = game_in_chat.player_o
      end
      check_game_status bot, game_in_chat
    end

    def process_message(bot, message)
      return if message.text.nil?

      chat_id = message.chat.id
      user = message.from
      create_stats_if_missing chat_id
      if message.text.include? '/start_game'
        waiting_for_game_start bot, user, chat_id
      elsif message.text.include? '/my_stats'
        stats = @stats[chat_id][user.id]
        unless stats
          bot.api.send_message chat_id: chat_id, text: 'Вы пока не участвовали в играх в этой группе!'
          return
        end
        text = "Начато игр: #{stats[:games_started]}, завершено игр: #{stats[:games_completed]}."
        if stats[:games_completed] != 0
          text += "\nПобеды: #{stats[:wins]}, поражения: #{stats[:losses]}, ничьи: #{stats[:draws]}." \
            "\nПроцент побед = #{(Float(stats[:wins]) / stats[:games_completed]) * 100}%."
          text += "\nВы чемпион этой группы!" if @stats[chat_id][:general_stats][:champion] == user.id
          if @stats[chat_id][:general_stats][:last_winner] == user.id
            text += "\nВам принадлежит последняя победа в этой группе!"
          elsif @stats[chat_id][:general_stats][:last_loser] == user.id
            text += "\nВам принадлежит последнее поражение в этой группе.."
          end
          bot.api.send_message chat_id: chat_id, text: text
        end
      elsif message.text.include? '/general_stats'
        stats = @stats[chat_id][:general_stats]
        unless stats
          bot.api.send_message chat_id: chat_id, text: 'В этой группе не проходило игр!'
          return
        end
        text = "Начато игр: #{stats[:total_games_started]}, завершено игр: #{stats[:total_games_completed]}." \
          "\nСыграно вничью: #{stats[:total_draws]}.\n"
        text += if stats[:champion].nil?
                  'В этой группе пока нет чемпиона...'
                else
                  "@#{(get_user_by_id bot, chat_id, stats[:champion]).username} -- чемпион этой группы!"
                end
        if stats[:last_winner]
          text += "\n@#{(get_user_by_id bot, chat_id, stats[:last_winner]).username}" \
          ' -- последний, кто одержал победу в этой группе!'
        end
        if stats[:last_loser]
          text += "\n@#{(get_user_by_id bot, chat_id, stats[:last_loser]).username}" \
          '-- последний, кто потерпел поражение в этой группе!'
        end
        bot.api.send_message chat_id: chat_id, text: text
      end
    end

    def create_stats_if_missing(chat_id)
      @stats[chat_id] = {} unless @stats[chat_id]
      return if @stats[chat_id][:general_stats]

      @stats[chat_id][:general_stats] =
        { total_games_started: 0, total_games_completed: 0, total_draws: 0 }
    end

    def get_user_by_id(bot, chat_id, user_id)
      (bot.api.get_chat_member chat_id: chat_id, user_id: user_id).user
    end

    def update_stats
      File.write 'stats.yml', @stats.to_yaml
    end

    def load_stats
      @stats = YAML.load_file 'stats.yml'
      @stats ||= {}
    end

    def save_games
      File.write 'games.yml', @games.transform_values(&:to_hash).to_yaml
    end

    def load_games
      games = YAML.load_file 'games.yml'
      @games = games&.transform_values { |game| GameState.from_hash game }
      @games ||= {}
    end

    def waiting_for_game_start(bot, user, chat_id)
      return 'Вы уже в очереди!' if @stats[chat_id][:waiting_for_game_start] == user.id

      unless @stats[chat_id][:waiting_for_game_start]
        @stats[chat_id][:waiting_for_game_start] = user.id
        update_stats
        b = Telegram::Bot::Types::InlineKeyboardButton.new text: 'Присоединиться', callback_data: 'join'
        kb = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: [[b]]
        bot.api.send_message chat_id: chat_id,
                             text: "#{(get_user_by_id bot, chat_id, @stats[chat_id][:waiting_for_game_start])
                                      .first_name} желает начать игру!",
                             reply_markup: kb
        return 'Добавлены в очередь!'
      end
      return 'В этом чате уже идёт игра!' if @games[chat_id]

      handle_start bot, chat_id, get_user_by_id(bot, chat_id, @stats[chat_id][:waiting_for_game_start]), user
      @stats[chat_id].delete :waiting_for_game_start
      update_stats
      save_games
      "Успешно присоединились к игре с #{get_user_by_id(bot, chat_id, @games[chat_id].player_x).first_name}!"
    end

    def create_player_stats_if_missing(chat_id, player_x, player_o)
      unless @stats[chat_id][player_x]
        @stats[chat_id][player_x] =
          { wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0 }
      end
      unless @stats[chat_id][player_o]
        @stats[chat_id][player_o] =
          { wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0 }
      end
    end

    def handle_start(bot, chat_id, player_x, player_o)
      create_player_stats_if_missing chat_id, player_x.id, player_o.id
      @stats[chat_id][player_x.id][:games_started] += 1
      @stats[chat_id][player_o.id][:games_started] += 1
      @stats[chat_id][:general_stats][:total_games_started] += 1
      update_stats

      game = TicTacToe::GameState.new player_x.id, player_o.id, chat_id
      @games[chat_id] = game
      msg = bot.api.send_message chat_id: chat_id,
                                 text: 'Игра началась! Ходит ❌:' \
                                 "#{get_user_by_id(bot, chat_id, @games[chat_id].player_x).first_name}.",
                                 reply_markup: render_keyboard(game.board)
      game.message_id = msg.message_id
      @games[chat_id] = game
    end

    def handle_move(bot, rq)
      chat_id = rq.message.chat.id
      user = rq.from
      game = @games[chat_id]
      return unless game

      unless game.valid_turn? user
        bot.api.answer_callback_query callback_query_id: rq.id, text: 'Сейчас не ваш ход!'
        return
      end

      row, col = rq.data.split('_')[1..2].map(&:to_i)

      if game.make_move(row, col)
        bot.api.edit_message_text(
          chat_id: game.chat_id,
          message_id: game.message_id,
          text: "Ходит #{if game.current_player == 'X'
                           "❌: #{get_user_by_id(bot, chat_id, @games[chat_id].player_x).first_name}"
                         else
                           "⭕: #{get_user_by_id(bot, chat_id, @games[chat_id].player_o).first_name}"
                         end}!"
        )
        bot.api.edit_message_reply_markup chat_id: game.chat_id,
                                          message_id: game.message_id,
                                          reply_markup: render_keyboard(game.board)
        check_game_status bot, game
      end
      save_games
      bot.api.answer_callback_query callback_query_id: rq.id
    end

    def check_game_status(bot, game)
      return unless game.winner

      chat_id = game.chat_id
      create_player_stats_if_missing chat_id, game.player_x, game.player_o
      @stats[chat_id][game.player_o][:games_completed] += 1
      @stats[chat_id][game.player_x][:games_completed] += 1
      @stats[chat_id][:general_stats][:total_games_completed] += 1
      if game.winner == 'Draw'
        text = 'Игра окончена! Ничья 🤝'
        @stats[chat_id][game.player_x][:draws] += 1
        @stats[chat_id][game.player_o][:draws] += 1
        @stats[chat_id][:general_stats][:total_draws] += 1
        update_stats
      else

        winner = game.winner == 'X' ? game.player_x : game.player_o
        loser = game.winner == 'X' ? game.player_o : game.player_x
        @stats[chat_id][winner][:wins] += 1
        @stats[chat_id][:general_stats][:last_winner] = winner
        @stats[chat_id][loser][:losses] += 1
        @stats[chat_id][:general_stats][:last_loser] = loser
        if @stats[chat_id][:general_stats][:champion].nil? || @stats[chat_id][:general_stats][:champion] == loser
          @stats[chat_id][:general_stats][:champion] = winner
        end
        update_stats
        win_icon  = game.winner == 'X' ? '❌' : '⭕'
        lose_icon = game.winner == 'X' ? '⭕' : '❌'

        text = "🎉 ИГРА ОКОНЧЕНА! 🎉\n\n" \
               "🏆 Победитель: #{get_user_by_id(bot, chat_id, winner).first_name} (#{win_icon})\n" \
               "💀 Проигравший: #{get_user_by_id(bot, chat_id, loser).first_name} (#{lose_icon})"
      end
      bot.api.send_message chat_id: chat_id, text: text
      @games.delete chat_id
    end

    def render_keyboard(board)
      kb = board.each_with_index.map do |row_array, row_idx|
        row_array.each_with_index.map do |cell, col_idx|
          label = cell.nil? ? ' ' : cell
          Telegram::Bot::Types::InlineKeyboardButton.new text: label,
                                                         callback_data: "move_#{row_idx}_#{col_idx}"
        end
      end
      Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: kb
    end
  end
end
