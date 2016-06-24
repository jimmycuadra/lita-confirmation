require "net/smtp"
require "rotp"
require "rqrcode"

module Lita
  module Handlers
    class Confirmation < Handler
      # block - never use 2fa; allow; require - only allow 2fa
      config :twofactor_default, required: false, type: [:block, :allow, :require], default: :block

      # If users can re-enroll or remove themselves, there is no true "second factor"
      # protection as control of Slack account lets an attacker re-enroll, obtain a new TOTP secret,
      # and generate OTP passwords. This can be set to false during a transition to 2FA.
      config :twofactor_secure, required: false, type: [TrueClass, FalseClass], default: true

      config :smtp_host, required: false, type: String, default: 'localhost'
      config :smtp_port, required: false, type: Fixnum, default: 25
      config :from_email, required: false, type: String, default: 'example@example.com'

      route /^confirm\s+([a-f0-9]{6})$/i, :confirm, command: true, help: {
        t("confirm_help.key") => t("confirm_help.value")
      }

      route /^confirm\s+([a-f0-9]{6})\s+([0-9]{6})$/i, :totp_confirm, command: true, help: {
        t("confirm_totp_help.key") => t("confirm_totp_help.value")
      }

      route /^confirm\s+2fa\s+enroll\s+(.*)\s*$/i,
        :enroll, command:true, help: { t("enroll_help.key") => t("enroll_help.value") }

      route /^confirm\s+2fa\s+remove$/i, :remove_self, command: true, help: {
        t("remove_help.key") => t("remove_help.value")
      }

      route /^confirm\s+2fa\s+remove\s+(\S+)$/i, :remove, command: true

      def confirm(response)
        code = response.matches[0][0]
        command = Extensions::Confirmation::UnconfirmedCommand.find(code)

        unless command
          response.reply(t("invalid_code", code: code))
          return
        end

        if command.twofactor
          response.reply(t("totp_not_provided"))
        else
          call_command(command, code, response)
        end
      end

      def totp_confirm(response)
        code = response.matches[0][0]
        command = Extensions::Confirmation::UnconfirmedCommand.find(code)

        unless command
          response.reply(t("invalid_code", code: code))
          return
        end

        totp_secret = redis.hget(response.user.id, "totp")
        unless totp_secret
          response.reply(t("totp_not_enrolled"))
          return
        end

        totp = ROTP::TOTP.new(totp_secret)
        # Attempting to 2FA verify a non-2FA confirmation is not a bad thing
        if totp.verify(response.matches[0][1]) || !command.twofactor
          call_command(command, code, response)
        else
          response.reply(t("totp_incorrect_otp"))
        end
      end

      def enroll(response)
        email = response.matches[0][0]
        unless email =~ /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/
          response.reply(t("enroll_email_failed_validation"))
          return
        end

        totp = ROTP::Base32.random_base32
        unless redis.hget(response.user.id, "totp") && config.twofactor_secure
          begin
            send_enroll_email(response.user, email, totp)
            redis.hset(response.user.id, "totp", totp)
            response.reply(t("enrolled"))
          rescue Exception => e
            response.reply(t("email_error", error: e.message))
          end
        else
          response.reply(t("must_remove_to_reenroll"))
        end
      end

      def remove_self(response)
        if config.twofactor_secure && !privileged_user?(response.user)
          response.reply(t("remove_requires_admin"))
        else
          redis.hdel(response.user.id, 'totp')
          response.reply(t("removed", user: "You"))
        end
      end

      def remove(response)
        user = Lita::User.find_by_mention_name(response.matches[0][0])

        if !privileged_user?(response.user)
          response.reply(t("remove_requires_admin"))
        else
          if user
            redis.hdel(user.id, 'totp')
            response.reply(t("removed", user: user.name))
          else
            response.reply(t("remove_no_such_user"))
          end
        end
      end

      private

      def privileged_user?(user)
         robot.auth.user_in_group?(user, :admin) || robot.auth.user_in_group?(user, :confirmation_admin)
      end

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

      def send_enroll_email(user, email, totp_secret)
        totp = ROTP::TOTP.new(totp_secret)
        provisioning_url = "otpauth://totp/OfficerURL:#{email}?secret=#{totp_secret}&issuer=OfficerURL"
        qrcode = RQRCode::QRCode.new(provisioning_url)

        message = <<MESSAGE_END
From: "#{robot.name}" <#{config.from_email}>
To: "#{user.name}" <#{email}>
MIME-Version: 1.0
Content-type: multipart/mixed; boundary=NEXTPART
#{t("enroll_email", robot_name: robot.name, user_name: user.name, secret: totp_secret )}

--NEXTPART
Content-Type: image/png; name="qrcode.png"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="qrcode.png"

#{[qrcode.as_png(size: 640).to_s].pack("m")}

MESSAGE_END

        Net::SMTP.start(config.smtp_host, config.smtp_port) do |smtp|
          smtp.send_message message, 'devnull@pagerduty.com', email
        end
      end
    end

    Lita.register_handler(Confirmation)
  end
end
