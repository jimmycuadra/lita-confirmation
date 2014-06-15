require "securerandom"

module Lita
  module Extensions
    class Confirmation
      class UnconfirmedCommand
        attr_reader :code, :handler, :message, :robot, :route, :options

        class << self
          def find(code)
            confirmations[code]
          end

          def confirmations
            @confirmations ||= {}
          end
        end

        def initialize(handler, message, robot, route, options)
          @handler = handler
          @message = message
          @robot = robot
          @route = route
          @options = Hash === options ? options : {}
          @code = SecureRandom.hex(3)
          self.class.confirmations[code] = self
        end

        def call(response)
          if disallow_self?(response.user)
            response.reply("Confirmation #{code} must come from a different user.")
            return
          end

          handler.dispatch_to_route(route, robot, message)
        end

        private

        def disallow_self?(confirming_user)
          disallowed = options.key?(:allow_self) ? !options[:allow_self] : false
          true if disallowed && message.user == confirming_user
        end
      end
    end
  end
end
