require "securerandom"

module Lita
  module Extensions
    class Confirmation
      class UnconfirmedCommand
        attr_reader :code, :handler, :message, :robot, :route

        class << self
          def find(code)
            confirmations.delete(code)
          end

          def confirmations
            @confirmations ||= {}
          end
        end

        def initialize(handler, message, robot, route)
          @handler = handler
          @message = message
          @robot = robot
          @route = route
          @code = SecureRandom.hex(3)
          self.class.confirmations[code] = self
        end

        def call
          handler.dispatch_to_route(route, robot, message)
        end
      end
    end
  end
end
