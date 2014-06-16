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
          call_command(command, code, response)
        else
          response.reply(t("invalid_code", code: code))
        end
      end

      private

      def call_command(command, code, response)
        case command.call(response.user)
        when :other_user_required
          response.reply(t("other_user_required", code: code))
        when :user_in_group_required
          response.reply(
            t("user_in_group_required", code: code, groups: command.groups.join(", "))
          )
        end
      end
    end

    Lita.register_handler(Confirmation)
  end
end
