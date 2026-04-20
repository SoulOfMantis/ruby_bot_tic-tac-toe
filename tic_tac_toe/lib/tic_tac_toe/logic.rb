module TicTacToe
  class Logic
    def self.create_board
      Array.new(3) { Array.new(3, nil) }
    end

    def self.check_winner(board)
      lines = []

      board.each { |row| lines << row }

      board.transpose.each { |col| lines << col }

      lines << [board[0][0], board[1][1], board[2][2]]
      lines << [board[0][2], board[1][1], board[2][0]]

      lines.each do |line|
        return 'X' if line.all? { |cell| cell == 'X' }
        return 'O' if line.all? { |cell| cell == 'O' }
      end

      nil
    end
  end

  class GameState
    attr_accessor :board, :current_player, :players, :chat_id, :message_id

    def initialize(first_player_id)
      @board = Logic.create_board
      @current_player = 'X'
      @players = { 'X' => first_player_id, 'O' => nil }
      @chat_id = nil
      @message_id = nil
    end

    def join_second_player(user_id)
      if @players['O'].nil? && user_id != @players['X']
        @players['O'] = user_id
      end
    end

    def current_player?(user_id)
      @players[@current_player] == user_id
    end

    def cell_empty?(row, col)
      @board[row][col].nil?
    end

    def make_move(row, col)
      @board[row][col] = @current_player
    end

    def switch_player
      @current_player = (@current_player == 'X' ? 'O' : 'X')
    end

    def winner
      Logic.check_winner(@board)
    end

    def draw?
      !@board.flatten.include?(nil)
    end

    def finished?
      winner || draw?
    end
  end
end