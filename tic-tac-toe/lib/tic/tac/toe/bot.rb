module Tic
  module Tac
    module Toe
      class Bot
        # Функция "Входа": берет данные из сообщения и возвращает игрока
        def self.handle_user(message)
          {
            id: message.chat.id,
            name: message.from.first_name,
            username: message.from.username
          }
        end
      end
    end
  end
end