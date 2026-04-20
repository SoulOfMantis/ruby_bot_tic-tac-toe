module TicTacToe
  class Logic
    def self.valid_move?(board, position)
      position.between?(0,8) && board[position] == " "
    end
    def self.create_board
      Array.new(3) { Array.new(3, nil) }
    end
    def self.check_winner(board)
      lines = [
        [[0,0], [0,1], [0,2]], [[1,0], [1,1], [1,2]], [[2,0], [2,1], [2,2]],
        [[0,0], [1,0], [2,0]], [[0,1], [1,1], [2,1]], [[0,2], [1,2], [2,2]],
        [[0,0], [1,1], [2,2]], [[0,2], [1,1], [2,0]]
      ]

      lines.each do |line|
        values = line.map { |r, c| board[r][c] }
        return values.first if values.uniq.count == 1 && !values.first.nil?
      end

      nil 
    end
  end
end
