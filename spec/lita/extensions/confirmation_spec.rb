require "spec_helper"

class Dangerous < Lita::Handler
  route /^danger$/, :danger, command: true, confirmation: true
  route /^danger self$/, :disallow_self, command: true, confirmation: { allow_self: false }
  route(
    /^danger restrict$/,
    :require_auth_group,
    command: true,
    confirmation: { restrict_to: :managers }
  )
  # route /^danger expire$/, :danger, command: true, confirmation: { expire_after: 0 }

  def danger(response)
    response.reply("Dangerous command executed!")
  end

  def disallow_self(response)
    response.reply("Dangerous command confirmed by another user and executed!")
  end

  def require_auth_group(response)
    response.reply("Dangerous command confirmed by a manager!")
  end
end

describe Dangerous, lita_handler: true do
  before do
    allow(Lita).to receive(:handlers).and_return([described_class, Lita::Handlers::Confirmation])
  end

  context "with confirmation: true" do
    it "requires confirmation" do
      send_command("danger")
      expect(replies.last).to match(/send the command "confirm [a-f0-9]{6}"/)
    end

    it "invokes the original route on confirmation" do
      send_command("danger")
      code = replies.last.match(/([a-f0-9]{6})"$/)[1]
      send_command("confirm #{code}")
      expect(replies.last).to eq("Dangerous command executed!")
    end

    it "responds with a message when an invalid code is provided" do
      send_command("danger")
      send_command("confirm 000000")
      expect(replies.last).to include("000000 is not a valid confirmation code")
    end
  end

  context "with allow_self: false" do
    it "responds with a message if the user tries to confirm their own command" do
      send_command("danger self")
      code = replies.last.match(/([a-f0-9]{6})"$/)[1]
      send_command("confirm #{code}")
      expect(replies.last).to include("must come from a different user")
    end

    it "invokes the original route on confirmation by another user" do
      send_command("danger self")
      code = replies.last.match(/([a-f0-9]{6})"$/)[1]
      send_command("confirm #{code}", as: Lita::User.create(123))
      expect(replies.last).to eq("Dangerous command confirmed by another user and executed!")
    end
  end

  context "with restrict_to: :managers" do
    let(:manager) do
      manager = Lita::User.create(123)
      allow(Lita::Authorization).to receive(:user_in_group?).with(
        manager, :managers
      ).and_return(true)
      manager
    end

    it "responds with a message if a user not in a required group tries to confirm a command" do
      send_command("danger restrict")
      code = replies.last.match(/([a-f0-9]{6})"$/)[1]
      send_command("confirm #{code}")
      expect(replies.last).to include(
        "must come from a user in one of the following authorization groups: managers"
      )
    end

    it "invokes the original route on confirmation by a manager" do
      send_command("danger restrict")
      code = replies.last.match(/([a-f0-9]{6})"$/)[1]
      send_command("confirm #{code}", as: manager)
      expect(replies.last).to include("confirmed by a manager")
    end
  end
end
