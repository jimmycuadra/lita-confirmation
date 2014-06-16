module Lita
  module Extensions
    class Confirmation
      attr_reader :handler, :message, :robot, :route

      def self.call(payload)
        new(
          payload.fetch(:handler),
          payload.fetch(:message),
          payload.fetch(:robot),
          payload.fetch(:route)
        ).call
      end

      def initialize(handler, message, robot, route)
        @handler = handler
        @message = message
        @robot = robot
        @route = route
      end

      def call
        if (options = route.extensions[:confirmation])
          message.reply(
            I18n.t(
              "lita.extensions.confirmation.request",
              code: UnconfirmedCommand.new(handler, message, robot, route, options).code
            )
          )

          return false
        end

        true
      end
    end

    Lita.register_hook(:validate_route, Confirmation)
  end
end
