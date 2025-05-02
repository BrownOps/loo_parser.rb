# frozen_string_literal: true

require "spec_helper"
require "date"

RSpec.describe LooParser::Parser do
  # Shared helper for creating DateTime objects
  def dt(year, month, day, hour, min, sec = 0)
    DateTime.new(year, month, day, hour, min, sec)
  end

  describe ".parse_datetime" do
    it "parses valid date and time strings" do
      expect(described_class.parse_datetime("2025-05-02", "14:30")).to eq(dt(2025, 5, 2, 14, 30))
    end

    it "parses valid date with single digit day" do
      expect(described_class.parse_datetime("2025-05-1", "11:00")).to eq(dt(2025, 5, 1, 11, 0))
    end

    it "parses valid date with single digit month" do
      expect(described_class.parse_datetime("2025-1-02", "09:05")).to eq(dt(2025, 1, 2, 9, 5))
    end

    it "parses valid date with single digit month and day" do
      expect(described_class.parse_datetime("2025-1-1", "08:00")).to eq(dt(2025, 1, 1, 8, 0))
    end

    it "parses valid date with different separator (/)" do
      expect(described_class.parse_datetime("2025/05/02", "14:30")).to eq(dt(2025, 5, 2, 14, 30))
    end

    it "returns nil for invalid month" do
      expect(described_class.parse_datetime("2025-13-01", "00:00")).to be_nil
    end

    it "returns nil for invalid date format string" do
      expect(described_class.parse_datetime("invalid-date", "10:00")).to be_nil
    end
  end

  describe ".parse_whatsapp_line" do
    it "parses a valid WhatsApp line with poop emoji" do
      line = "[02/05/25, 14:30:15] Alice: 💩"
      expected_ts = dt(2025, 5, 2, 14, 30, 15)
      expected_msg = LooParser::Parser::WhatsAppMessage.new(timestamp: expected_ts,
                                                            sender: "Alice", content: "💩")
      expect(described_class.parse_whatsapp_line(line)).to eq(expected_msg)
    end

    it "parses a valid normal WhatsApp line" do
      line = "[03/06/24, 10:00:00] Bob: Hello there"
      expected_ts = dt(2024, 6, 3, 10, 0, 0)
      expected_msg = LooParser::Parser::WhatsAppMessage.new(timestamp: expected_ts, sender: "Bob",
                                                            content: "Hello there")
      expect(described_class.parse_whatsapp_line(line)).to eq(expected_msg)
    end

    it "returns nil for a line with an invalid format" do
      line = "This is not a valid WhatsApp line"
      expect(described_class.parse_whatsapp_line(line)).to be_nil
    end

    it "returns nil for a line with an invalid date within the brackets" do
      line = "[32/13/25, 14:30:15] Alice: Test"
      expect(described_class.parse_whatsapp_line(line)).to be_nil
    end
  end

  describe LooParser::Parser::Analyzer do
    let(:analyzer) { described_class.new }
    let(:msg_struct) { LooParser::Parser::WhatsAppMessage }

    def get_result_for_sender(messages, sender_name)
      results = analyzer.analyze_messages(messages)
      sender_results = results.select { |r| r[:sender] == sender_name }
      expect(sender_results.count).to eq(1),
                                      "Expected 1 result for #{sender_name}, got #{sender_results.count}"
      sender_results.first
    end

    it "initializes with an empty sender shift hash defaulting to 0" do
      expect(analyzer.sender_shift).to be_a(Hash)
      expect(analyzer.sender_shift.default).to eq(0)
      expect(analyzer.sender_shift["anyone"]).to eq(0)
    end

    describe "#compute_status" do
      let(:message_time) { dt(2024, 6, 1, 12, 0) }

      it "returns :ok for recent times relative to message time (15 days)" do
        recent_poop = message_time - 15
        expect(analyzer.send(:compute_status, recent_poop, message_time)).to eq(:ok)
      end

      it "returns :ok for the same time as the message time" do
        live_poop_time = message_time
        expect(analyzer.send(:compute_status, live_poop_time, message_time)).to eq(:ok)
      end

      it "returns :alert for old times relative to message time (45 days)" do
        old_poop = message_time - 45
        expect(analyzer.send(:compute_status, old_poop, message_time)).to eq(:alert)
      end

      it "returns :ok when difference is exactly 30 days" do
        thirty_days_ago = message_time - 30
        expect(analyzer.send(:compute_status, thirty_days_ago, message_time)).to eq(:ok)
      end

      it "returns :alert when difference is slightly more than 30 days" do
        days_in_secs = 24 * 60 * 60
        thirty_days_plus_one_sec = Rational((30 * days_in_secs) + 1, days_in_secs)
        just_over_thirty_days_ago = message_time - thirty_days_plus_one_sec
        expect(analyzer.send(:compute_status, just_over_thirty_days_ago, message_time)).to eq(:alert)
      end

      it "returns :error for non-datetime poop_time input" do
        expect(analyzer.send(:compute_status, "not a datetime", message_time)).to eq(:error)
      end
    end

    it "handles poop_live message with default shift (0)" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 10, 0), sender: "Alice", content: "💩")
      res = get_result_for_sender([msg], "Alice")

      expect(res[:type]).to eq(:poop_live)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(msg.timestamp)
      expect(res[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Alice"]).to eq(0)
    end

    it "handles poop_live message with trailing text" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 22, 0), sender: "Jane", content: "💩 <edited>")
      res = get_result_for_sender([msg], "Jane")
      expect(res[:type]).to eq(:poop_live)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(msg.timestamp)
      expect(res[:status]).to eq(:ok)
    end

    it "handles toilet_set_shift and updates sender state" do
      msg1 = msg_struct.new(timestamp: dt(2024, 5, 1, 10, 0), sender: "Alice", content: "💩")
      msg2 = msg_struct.new(timestamp: dt(2024, 5, 1, 10, 5), sender: "Alice", content: "🚽 +2")
      results = analyzer.analyze_messages([msg1, msg2])
      res_set_shift = results.find { |r| r[:type] == :toilet_set_shift }

      expect(results.count).to eq(2)
      expect(res_set_shift[:sender]).to eq("Alice")
      expect(res_set_shift[:shift]).to eq(2)
      expect(res_set_shift[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Alice"]).to eq(2)
    end

    it "handles toilet_set_shift with trailing text" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 23, 30), sender: "Kevin",
                           content: "🚽 -1 Edited")
      res = get_result_for_sender([msg], "Kevin")
      expect(res[:type]).to eq(:toilet_set_shift)
      expect(res[:shift]).to eq(-1)
      expect(res[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Kevin"]).to eq(-1)
    end

    it "uses the set shift state for subsequent poop_live messages" do
      msg1 = msg_struct.new(timestamp: dt(2024, 5, 1, 10, 5), sender: "Alice", content: "🚽 +2")
      msg2 = msg_struct.new(timestamp: dt(2024, 5, 1, 11, 0), sender: "Alice", content: "💩")
      results = analyzer.analyze_messages([msg1, msg2])
      res_poop = results.find { |r| r[:type] == :poop_live }

      expect(res_poop[:sender]).to eq("Alice")
      expect(res_poop[:shift]).to eq(2)
      expect(res_poop[:poop_time]).to eq(msg2.timestamp)
      expect(res_poop[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Alice"]).to eq(2)
    end

    it "overrides state shift with poop_live_shift for that message only" do
      msg1 = msg_struct.new(timestamp: dt(2024, 5, 1, 10, 5), sender: "Alice", content: "🚽 +2")
      msg2 = msg_struct.new(timestamp: dt(2024, 5, 1, 12, 0), sender: "Alice", content: "💩 -1")
      results = analyzer.analyze_messages([msg1, msg2])
      res_poop_shift = results.find { |r| r[:type] == :poop_live_shift }

      expect(res_poop_shift[:sender]).to eq("Alice")
      expect(res_poop_shift[:shift]).to eq(-1)
      expect(res_poop_shift[:poop_time]).to eq(msg2.timestamp)
      expect(res_poop_shift[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Alice"]).to eq(2)
    end

    it "handles poop_past message with default shift and ok status" do
      msg_time = dt(2024, 5, 1, 13, 0)
      poop_time = dt(2024, 4, 15, 8, 0)
      msg = msg_struct.new(sender: "Bob", timestamp: msg_time,
                           content: "💩 #{poop_time.strftime("%Y-%m-%d %H:%M")}")
      res = get_result_for_sender([msg], "Bob")

      expect(res[:type]).to eq(:poop_past)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Bob"]).to eq(0)
    end

    it "handles poop_past message resulting in alert status" do
      msg_time = dt(2024, 5, 2, 0, 0)
      poop_time = msg_time - 31
      msg = msg_struct.new(sender: "Dave", timestamp: msg_time,
                           content: "💩 #{poop_time.strftime("%Y-%m-%d %H:%M")}")
      res = get_result_for_sender([msg], "Dave")

      expect(res[:type]).to eq(:poop_past)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:alert)
    end

    it "handles poop_past with flexible date formats (single digits)" do
      msg_time = dt(2024, 5, 1, 19, 0)
      poop_time = dt(2024, 4, 1, 9, 0)
      msg = msg_struct.new(sender: "Gina", timestamp: msg_time, content: "💩 2024-4-1 09:00")
      res = get_result_for_sender([msg], "Gina")

      expect(res[:type]).to eq(:poop_past)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:alert)
    end

    it "handles poop_past with single digit hour" do
      msg_time = dt(2024, 5, 1, 21, 0)
      poop_time = dt(2024, 4, 20, 3, 30)
      msg = msg_struct.new(sender: "Ian", timestamp: msg_time, content: "💩 2024-04-20 3:30")
      res = get_result_for_sender([msg], "Ian")

      expect(res[:type]).to eq(:poop_past)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:ok)
    end

    it "handles poop_past message with trailing text" do
      msg_time = dt(2024, 5, 1, 20, 0)
      poop_time = dt(2024, 4, 30, 15, 0)
      msg = msg_struct.new(sender: "Harry", timestamp: msg_time,
                           content: "💩 2024-04-30 15:00 some extra text")
      res = get_result_for_sender([msg], "Harry")

      expect(res[:type]).to eq(:poop_past)
      expect(res[:shift]).to eq(0)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:ok)
    end

    it "handles poop_past_shift message with specified shift and preserves state" do
      msg_time = dt(2024, 5, 1, 14, 0)
      poop_time = dt(2024, 4, 10, 9, 30)
      msg = msg_struct.new(sender: "Bob", timestamp: msg_time, content: "💩 +3 2024-04-10 09:30")
      res = get_result_for_sender([msg], "Bob")

      expect(res[:type]).to eq(:poop_past_shift)
      expect(res[:shift]).to eq(3)
      expect(res[:poop_time]).to eq(poop_time)
      expect(res[:status]).to eq(:ok)
      expect(analyzer.sender_shift["Bob"]).to eq(0)
    end

    it "handles unrecognized messages containing poop emoji" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 15, 0), sender: "Charlie",
                           content: "I saw a 💩")
      res = get_result_for_sender([msg], "Charlie")
      expect(res[:type]).to eq(:unrecognized_poop_emoji)
      expect(res[:status]).to eq(:error)
    end

    it "ignores messages without relevant emojis" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 16, 0), sender: "Alice",
                           content: "Hello world")
      results = analyzer.analyze_messages([msg])
      expect(results).to be_empty
    end

    it "handles poop_past with an invalid datetime string" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 17, 0), sender: "Eve",
                           content: "💩 2024-13-01 10:00")
      res = get_result_for_sender([msg], "Eve")
      expect(res[:type]).to eq(:poop_past)
      expect(res[:status]).to eq(:error)
      expect(res[:poop_time]).to be_nil
      expect(res[:error_details]).to eq(:invalid_datetime_format)
    end

    it "handles toilet_set_shift with an invalid shift number (non-matching pattern)" do
      msg = msg_struct.new(timestamp: dt(2024, 5, 1, 18, 0), sender: "Frank", content: "🚽 abc")
      res = get_result_for_sender([msg], "Frank")
      expect(res[:type]).to eq(:unrecognized_toilet_emoji)
      expect(res[:status]).to eq(:error)
      expect(analyzer.sender_shift["Frank"]).to eq(0)
    end
  end
end
