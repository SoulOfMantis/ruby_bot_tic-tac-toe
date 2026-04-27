# frozen_string_literal: true

require 'telegram/bot'
require_relative '../lib/tic_tac_toe/bot'
require_relative '../lib/tic_tac_toe/logic'
require 'rspec'
require 'yaml'

RSpec.describe TicTacToe::Bot do
  let(:token) { 'fake_token' }
  let(:bot) { described_class.new(token) }
  let(:chat_id) { 12_345 }

  let(:bot_api) { double('BotAPI') }

  before do
    allow(bot).to receive(:api).and_return(bot_api)
    allow(bot).to receive(:update_stats)
    bot.instance_variable_set(:@stats, { chat_id => { general_stats: {} } })
    bot.instance_variable_set(:@games, {})
  end

  let(:user) do
    double('User',
           id: 123,
           first_name: 'Mawa',
           username: 'mawa_dev')
  end

  let(:user2) do
    double('User',
           id: 456,
           first_name: 'Alex',
           username: 'alex_dev')
  end

  let(:message) do
    double('Message',
           from: user,
           chat: double('Chat', id: chat_id),
           text: nil)
  end

  let(:callback) do
    double('Callback',
           from: user,
           id: 'cb1',
           data: 'move_0_0',
           message: double('Msg', chat: double('Chat', id: chat_id)))
  end

  # -------------------------
  # PROCESS MESSAGE
  # -------------------------

  describe '#process_message' do
    context '/my_stats без данных' do
      before do
        allow(message).to receive(:text).and_return('/my_stats')
      end

      it 'сообщает что статистики нет' do
        expect(bot.api).to receive(:send_message).with(
          chat_id: chat_id,
          text: 'Вы пока не участвовали в играх в этой группе!'
        )

        bot.send(:process_message, bot, message)
      end
    end

    context '/general_stats без игр' do
      before do
        allow(message).to receive(:text).and_return('/general_stats')
        bot.instance_variable_set(:@stats, { chat_id => { general_stats: nil } })
      end

      it 'сообщает об отсутствии игр' do
        expect(bot.api).to receive(:send_message).with(
          chat_id: chat_id,
          text: 'В этой группе не проходило игр!'
        )

        bot.send(:process_message, bot, message)
      end
    end

    context '/start_game' do
      before do
        allow(message).to receive(:text).and_return('/start_game')
        allow(bot.api).to receive(:get_chat_member).and_return(double(user: user))
        allow(bot.api).to receive(:send_message)
      end

      it 'создает очередь' do
        expect(bot.api).to receive(:send_message).with(hash_including(text: /желает начать игру!/))
        bot.send(:process_message, bot, message)
      end
    end
  end

  # -------------------------
  # WAITING FOR GAME
  # -------------------------

  describe '#waiting_for_game_start' do
    before do
      allow(bot.api).to receive(:get_chat_member).and_return(double(user: user))
      allow(bot.api).to receive(:send_message)
    end

    it 'добавляет игрока в очередь' do
      result = bot.send(:waiting_for_game_start, bot, user, chat_id)

      expect(result).to eq('Добавлены в очередь!')
      expect(bot.instance_variable_get(:@stats)[chat_id][:waiting_for_game_start]).to eq(user.id)
    end

    it 'запрещает повторное добавление' do
      bot.instance_variable_get(:@stats)[chat_id][:waiting_for_game_start] = user.id

      result = bot.send(:waiting_for_game_start, bot, user, chat_id)
      expect(result).to eq('Вы уже в очереди!')
    end
  end

  # -------------------------
  # CALLBACK
  # -------------------------

  describe '#process_callback' do
    before do
      allow(bot.api).to receive(:answer_callback_query)
    end

    it 'отвечает join если игры нет' do
      callback = double('Callback',
                        from: user,
                        id: 'cb1',
                        data: 'join',
                        message: double('Msg', chat: double('Chat', id: chat_id)))

      allow(bot).to receive(:waiting_for_game_start).and_return('ok')

      expect(bot.api).to receive(:answer_callback_query).with(
        callback_query_id: 'cb1',
        text: 'ok'
      )

      bot.send(:process_callback, bot, callback)
    end
  end

  # -------------------------
  # RENDER KEYBOARD
  # -------------------------

  describe '#render_keyboard' do
    it 'создает 3x3 поле' do
      board = Array.new(3) { Array.new(3, nil) }

      keyboard = bot.send(:render_keyboard, board)

      expect(keyboard.inline_keyboard.size).to eq(3)
      expect(keyboard.inline_keyboard.first.size).to eq(3)
    end

    it 'отображает X и O' do
      board = [
        ['X', nil, 'O'],
        [nil, 'X', nil],
        ['O', nil, 'X']
      ]

      keyboard = bot.send(:render_keyboard, board)

      expect(keyboard.inline_keyboard[0][0].text).to eq('X')
      expect(keyboard.inline_keyboard[0][1].text).to eq(' ')
      expect(keyboard.inline_keyboard[0][2].text).to eq('O')
    end
  end

  # -------------------------
  # GAME STATUS
  # -------------------------

  describe '#check_game_status' do
    let(:player_x) { double('User', id: 1, first_name: 'X') }
    let(:player_o) { double('User', id: 2, first_name: 'O') }

    let(:game) do
      TicTacToe::GameState.new(player_x, player_o, chat_id)
    end

    before do
      bot.instance_variable_set(:@stats, {
        chat_id => {
          general_stats: { total_games_started: 0, total_games_completed: 0, total_draws: 0 },
          1 => { wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0 },
          2 => { wins: 0, losses: 0, draws: 0, games_started: 0, games_completed: 0 }
        }
      })

      allow(bot.api).to receive(:send_message)
    end

    it 'обрабатывает победу' do
      game.instance_variable_set(:@winner, 'X')

      expect(bot.api).to receive(:send_message).with(chat_id: chat_id, text: /Победитель/)

      bot.send(:check_game_status, bot, game)

      stats = bot.instance_variable_get(:@stats)[chat_id]

      expect(stats[1][:wins]).to eq(1)
      expect(stats[2][:losses]).to eq(1)
    end

    it 'обрабатывает ничью' do
      game.instance_variable_set(:@winner, 'Draw')

      expect(bot.api).to receive(:send_message).with(chat_id: chat_id, text: /Ничья/)

      bot.send(:check_game_status, bot, game)

      stats = bot.instance_variable_get(:@stats)[chat_id]

      expect(stats[1][:draws]).to eq(1)
      expect(stats[2][:draws]).to eq(1)
    end
  end

  # -------------------------
  # FILE SAVE / LOAD
  # -------------------------

  describe '#update_stats и #load_stats' do
    let(:test_file) { 'stats.yml' }
    let(:data) { { test: 'data' } }

    after do
      File.delete(test_file) if File.exist?(test_file)
    end

    it 'сохраняет и загружает файл' do
      allow(bot).to receive(:update_stats).and_call_original

      bot.instance_variable_set(:@stats, data)
      bot.send(:update_stats)

      new_bot = described_class.new(token)
      new_bot.send(:load_stats)

      expect(new_bot.instance_variable_get(:@stats)).to eq(data)
    end
  end
end