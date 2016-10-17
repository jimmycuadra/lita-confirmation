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
        # As this is not a handler, we do not get an automatic @redis
        @redis = Redis::Namespace.new('handlers:confirmation', redis: Lita.redis)
      end

      def call
        if (options = route.extensions[:confirmation])
          if twofactor_enabled_for_user?(message.user.id) && route_allows_twofactor?(options)
            # 2FA route
            cmd = UnconfirmedCommand.new(handler, message, robot, route, true, options)
            message.reply(
              I18n.t(
                "lita.extensions.confirmation.twofactor_request",
                prefix: @robot.alias ? @robot.alias : "#{@robot.mention_format(@robot.mention_name)} ",
                code: cmd.code
              )
            )

          elsif !twofactor_enabled_for_user?(message.user.id) && route_requires_twofactor?(options)
            message.reply(I18n.t("lita.extensions.confirmation.requires_2fa"))

          else
            # 1FA route
            cmd = UnconfirmedCommand.new(handler, message, robot, route, false, options)
            message.reply(
              I18n.t(
                "lita.extensions.confirmation.request",
                prefix: @robot.alias ? @robot.alias : "#{@robot.mention_format(@robot.mention_name)} ",
                code: cmd.code
              )
            )
          end

          return false
        end

        true
      end

      def twofactor_enabled_for_user?(user_id)
        !@redis.hget(user_id, 'totp').nil?
      end

      def parse_twofactor_option(options)
        if options.is_a?(Hash) && options[:twofactor]
          unless %i(block allow require).include? options[:twofactor]
            raise "#{options[:twofactor]} is not a valid value for Confirmation's twofactor option"
          end
          options[:twofactor]
        else
          Lita.config.handlers.confirmation.twofactor_default
        end
      end

      def route_allows_twofactor?(options)
        %i(allow require).include? parse_twofactor_option(options)
      end

      def route_requires_twofactor?(options)
        :require == parse_twofactor_option(options)
      end
    end

    Lita.register_hook(:validate_route, Confirmation)
  end
end
