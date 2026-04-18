module Tic
  module Tac
    module Toe
      class Logic

        def self.valid_move?(board, position)
          position.between?(0,8) && board[position] == " "
        end
        
        # Функция проверки победы
        def self.check_winner(board)
          wins = [
            [0,1,2], [3,4,5], [6,7,8], 
            [0,3,6], [1,4,7], [2,5,8], 
            [0,4,8], [2,4,6]          
          ]

          wins.each do |line|
            if board[line[0]] != " " && board[line[0]] == board[line[1]] && board[line[1]] == board[line[2]]
              return board[line[0]] 
            end
          end
          nil
        end
      end
    end
  end
end