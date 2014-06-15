module Lita
  module Handlers
    class Confirmation < Handler
      route /^confirm\s+([a-f0-9]{6})$/i, :confirm, command: true, help: {
        t("help.key") => t("help.value")
      }

      def confirm(response)
        code = response.matches[0][0]

        command = Extensions::Confirmation::UnconfirmedCommand.find(code)

        if command
          command.call(response)
        else
          response.reply(t("invalid_code", code: code))
        end
      end
    end

    Lita.register_handler(Confirmation)
  end
end
