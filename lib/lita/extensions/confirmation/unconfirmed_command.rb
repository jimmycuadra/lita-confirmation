require "securerandom"

module Lita
  module Extensions
    class Confirmation
      class UnconfirmedCommand
        attr_reader :allow_self, :code, :groups, :handler, :message, :robot, :route, :timer_thread, :twofactor

        class << self
          def find(code)
            confirmations[code]
          end

          def confirmations
            @confirmations ||= {}
          end

          def reset
            confirmations.clear
          end
        end

        def initialize(handler, message, robot, route, twofactor, options)
          @handler = handler
          @message = message
          @robot = robot
          @route = route
          @twofactor = twofactor

          @code = SecureRandom.hex(3)
          self.class.confirmations[code] = self

          process_options(options)
        end

        def call(user)
          return :other_user_required if disallow_self?(user)
          return :user_in_group_required unless in_required_group?(user)

          expire
          timer_thread.kill if timer_thread
          handler.dispatch_to_route(route, robot, message)
        end

        private

        def disallow_self?(confirming_user)
          true if !allow_self && message.user == confirming_user
        end

        def expire
          self.class.confirmations.delete(code)
        end

        def in_required_group?(user)
          return true unless groups

          groups.any? { |group| robot.auth.user_in_group?(user, group) }
        end

        def process_options(options)
          options = Hash === options ? options : {}

          @allow_self = options.key?(:allow_self) ? options[:allow_self] : true
          @groups = options.key?(:restrict_to) ? Array(options[:restrict_to]) : nil

          expiry = options.key?(:expire_after) ? options[:expire_after] : 60
          @timer_thread = Thread.new do
            Lita::Timer.new(interval: expiry) do
              expire
            end.start
          end
        end
      end
    end
  end
end
