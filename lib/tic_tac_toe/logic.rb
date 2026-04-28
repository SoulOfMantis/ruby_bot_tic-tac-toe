# frozen_string_literal: true

require 'telegram/bot'

module TicTacToe
  class GameState
    attr_accessor :board, :current_player, :player_x, :player_o, :winner, :chat_id, :message_id

    def initialize(player_x, player_o, chat_id)
      @board = Array.new(3) { Array.new 3, nil }
      @current_player = 'X'
      @player_x = player_x
      @player_o = player_o
      @winner = nil
      @chat_id = chat_id
      @message_id = nil
    end

    def to_hash
      { board: board, current_player: current_player, player_x: player_x, player_o: player_o,
        winner: winner, chat_id: chat_id, message_id: message_id }
    end

    def self.from_hash(hash)
      game = GameState.new hash[:player_x], hash[:player_o], hash[:chat_id]
      game.board = hash[:board]
      game.current_player = hash[:current_player]
      game.winner = hash[:winner]
      game.message_id = hash[:message_id]
      game
    end

    def contains_user_id(user_id)
      player_o == user_id || player_x == user_id
    end

    def valid_turn?(user)
      return false if @winner

      if @current_player == 'X'
        @player_x == user.id
      else
        @player_o == user.id
      end
    end

    def make_move(row, col)
      return false if @board[row][col] || @winner

      @board[row][col] = @current_player
      @winner = check_winner
      @current_player = (@current_player == 'X' ? 'O' : 'X') unless @winner
      true
    end

    def check_winner
      lines = []
      3.times do |i|
        lines << @board[i]
        lines << [@board[0][i], @board[1][i], @board[2][i]]
      end
      lines << [@board[0][0], @board[1][1], @board[2][2]]
      lines << [@board[0][2], @board[1][1], @board[2][0]]

      lines.each do |line|
        return 'X' if line.all? { |cell| cell == 'X' }
        return 'O' if line.all? { |cell| cell == 'O' }
      end
      return 'Draw' if @board.flatten.none?(&:nil?)

      nil
    end
  end
end
