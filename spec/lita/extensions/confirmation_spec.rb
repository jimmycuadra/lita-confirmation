require "spec_helper"

class Dangerous < Lita::Handler
  route /^danger$/, :danger, command: true, confirmation: true
  # route /^danger self$/, :danger, command: true, confirmation: { allow_self: false }
  # route(
  #   /^danger restrict$/,
  #   :danger,
  #   command: true,
  #   confirmation: { restrict_to: :dangerous_command_admins }
  # )
  # route /^danger expire$/, :danger, command: true, confirmation: { expire_after: 0 }

  def danger(response)
    response.reply("Dangerous command executed!")
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
end
