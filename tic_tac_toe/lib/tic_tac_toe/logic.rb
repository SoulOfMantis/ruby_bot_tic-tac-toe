module TicTacToe
  class GameState
    attr_accessor :board, :current_player, :player_x, :player_o, :name_x, :name_o, :winner, :chat_id, :message_id

    def initialize
      @board = Array.new(3) { Array.new(3, nil) }
      @current_player = 'X'
      @player_x = nil 
      @player_o = nil 
      @name_x = nil 
      @name_o = nil 
      @winner = nil
      @chat_id = nil
      @message_id = nil
    end

    def valid_turn?(user_id)
      return false if @winner 
      
      if @current_player == 'X'
        @player_x == user_id
      else
        if @player_o.nil? && user_id != @player_x
          @player_o = user_id
        end
        @player_o == user_id
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