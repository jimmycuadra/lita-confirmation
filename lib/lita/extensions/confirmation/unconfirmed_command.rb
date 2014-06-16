require "securerandom"

module Lita
  module Extensions
    class Confirmation
      class UnconfirmedCommand
        attr_reader :allow_self, :code, :groups, :handler, :message, :robot, :route

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

          options = Hash === options ? options : {}

          @allow_self = options.key?(:allow_self) ? options[:allow_self] : true
          @groups = options.key?(:restrict_to) ? Array(options[:restrict_to]) : nil

          @code = SecureRandom.hex(3)

          self.class.confirmations[code] = self
        end

        def call(user)
          return :other_user_required if disallow_self?(user)
          return :user_in_group_required unless in_required_group?(user)

          handler.dispatch_to_route(route, robot, message)
        end

        private

        def disallow_self?(confirming_user)
          true if !allow_self && message.user == confirming_user
        end

        def in_required_group?(user)
          return true unless groups

          groups.any? { |group| Lita::Authorization.user_in_group?(user, group) }
        end
      end
    end
  end
end
