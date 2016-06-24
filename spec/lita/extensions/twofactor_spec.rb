require "spec_helper"
require "net/smtp"
require "rotp"

class Important < Lita::Handler
  route /^unimportant$/, :unimportant, command: true, confirmation: { twofactor: :block }

  route /^danger$/, :danger, command: true, confirmation: { twofactor: :allow }

  route /^critical$/, :critical, command: true, confirmation: { twofactor: :require }

  route /^invalid$/, :critical, command: true, confirmation: { twofactor: :foobar }

  def unimportant(response)
    response.reply("Trivial command executed!")
  end

  def danger(response)
    response.reply("Important command executed!")
  end

  def critical(response)
    response.reply("Critical command executed!")
  end
end

describe Lita::Handlers::Confirmation, lita_handler: true, additional_lita_handlers: Important do
  before do
    registry.register_hook(:validate_route, Lita::Extensions::Confirmation)
    Lita::Extensions::Confirmation::UnconfirmedCommand.reset
  end

  let(:mailer) do
    mailer = double(Net::SMTP)
    @messages = []
    allow(mailer).to receive(:send_message) do |msg, from, to|
      @messages << {
        msg: msg,
        to: to
      }
    end
    mailer
  end

  it "does not accept invalid config values" do
    expect { send_command("invalid") }.to raise_error(RuntimeError, /not a valid value for Confirmation's twofactor option/)
  end

  context "with user not enrolled into 2fa" do
    before do
      allow(Net::SMTP).to receive(:start).and_yield(mailer)
    end

    it "does not allow routes that require 2fa" do
      send_command("critical")
      expect(replies.last).to match(/you have not set up two-factor authentication/)
    end

    it "lets the user enroll" do
      send_command("confirm 2fa enroll foo@example.com")
      expect(replies.last).to match(/You are now enrolled/)
      expect(@messages.size).to eq(1)
      expect(@messages.first[:to]).to eq('foo@example.com')
    end

    it "does not allow a user to enroll twice" do
      send_command("confirm 2fa enroll foo@example.com")
      send_command("confirm 2fa enroll foo@example.com")
      expect(replies.last).to match(/you cannot re-enroll/)
      expect(@messages.size).to eq(1)
    end

    it "does not accept junk as email address" do
      send_command("confirm 2fa enroll foo")
      expect(replies.last).to match(/does not appear valid/)
    end

    it "does not allow a non-privileged user to remove themselves" do
      send_command("confirm 2fa enroll foo@example.com")
      send_command("confirm 2fa remove")
      expect(replies.last).to match(/this action can only be performed by a Lita administrator/)
    end

    it "does not allow a non-privileged user to remove others" do
      send_command("confirm 2fa remove joe")
      expect(replies.last).to match(/this action can only be performed by a Lita administrator/)
    end
  end

  context "with email being sad" do
    before do
      sad_mailer = double(Net::SMTP)
      allow(sad_mailer).to receive(:send_message) do
        raise "The mailer is sad, no mail can be sent"
      end
       allow(Net::SMTP).to receive(:start).and_yield(sad_mailer)
    end

    it 'does not enroll a user when email cannot be sent' do
      send_command("confirm 2fa enroll foo@example.com")
      expect(replies.last).to match(/Could not send email/)
    end
  end

  context "with lax security setings" do
    before do
      allow_any_instance_of(Lita::Handlers::Confirmation).to receive(:config)
        .and_return(double('Lita::Configuration', twofactor_secure: false))
    end

    it "lets the user opt out" do
      send_command("confirm 2fa remove")
      expect(replies.last).to match(/You will no longer be prompted/)
    end
  end

  context "with user enrolled into 2fa" do
    before do
      allow(Net::SMTP).to receive(:start).and_yield(mailer)
      send_command("confirm 2fa enroll foo@example.com")
      code = /([a-z0-9]{16})/.match(@messages.first[:msg])[0]
      @totp = ROTP::TOTP.new(code)
    end

    it "sends a 2fa prompt when allowed" do
      send_command("danger")
      expect(replies.last).to match(/YOUR_ONE_TIME_PASSWORD/)
    end

    it "invokes the original route on confirmation" do
      send_command("danger")
      code = replies.last.match(/\s([a-f0-9]{6})\s/)[1]
      send_command("confirm #{code} #{@totp.now}")
      expect(replies.last).to eq("Important command executed!")
    end

    it "requires the OTP" do
      send_command("danger")
      code = replies.last.match(/\s([a-f0-9]{6})\s/)[1]
      send_command("confirm #{code}")
      expect(replies.last).to match(/requires a one-time password in addition to the command code/)
    end

    it "does not accept correct OTP but invalid command code" do
      send_command("danger")
      code = ((replies.last.match(/\s([a-f0-9]{6})\s/)[1].to_i(16) + 1) % 0x1000000).to_s(16)
      send_command("confirm #{code} #{@totp.now}")
      expect(replies.last).to match(/is not a valid confirmation code/)
    end

    it "rejects an incorrect OTP" do
      send_command("danger")
      code = replies.last.match(/\s([a-f0-9]{6})\s/)[1]
      bad_otp = (@totp.now.to_i + 1) % 1000000
      send_command("confirm #{code} #{bad_otp}")
      expect(replies.last).to match(/one-time password you have provided is not correct/)
    end

    it "does not allow a non-enrolled user to confirm a 2fa prompt" do
      send_command("danger")
      code = replies.last.match(/\s([a-f0-9]{6})\s/)[1]
      manager = Lita::User.create(123)
      send_command("confirm #{code} 000000", as: manager)
      expect(replies.last).to match(/Please enroll in two-factor confirmation/)
    end
  end

  context "with admin user" do
    let(:boss) do
      boss = Lita::User.create(123)
      robot.auth.add_user_to_group!(boss, :confirmation_admin)
      boss
    end

    let(:minion) do
      minion = Lita::User.create(456, {'mention_name': 'panda'})
      minion
    end

    it 'does not let the boss unenroll a non-existent user' do
      send_command("confirm 2fa remove joe", as: boss)
      expect(replies.last).to match(/No such user/)
    end

    it 'unenrolls another user' do
      send_command("confirm 2fa enroll foo@example.com", as: minion)
      send_command("confirm 2fa remove panda", as: boss)
      expect(replies.last).to match(/will no longer be prompted/)
    end
  end
end
