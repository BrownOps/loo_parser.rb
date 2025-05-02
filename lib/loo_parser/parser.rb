# frozen_string_literal: true

require "date"
require "json"

module LooParser
  # Core logic for parsing WhatsApp chat logs
  module Parser
    # Represents a parsed WhatsApp message
    WhatsAppMessage = Struct.new(:timestamp, :sender, :content, keyword_init: true)

    # Regex patterns for message types (order matters)
    PATTERNS = {
      toilet_set_shift: /^🚽\s*([+-]?\d+)(?:\s+.*)?$/,
      poop_live_shift: /^💩\s*([+-]\d+)$/,
      poop_past_shift: /^💩\s*([+-]\d+)\s+(\d{4}-\d{1,2}-\d{1,2})\s+(\d{1,2}:\d{2})(?:\s+.*)?$/,
      poop_past: /^💩\s*(\d{4}-\d{1,2}-\d{1,2})\s+(\d{1,2}:\d{2})(?:\s+.*)?$/,
      poop_live: /^💩/
    }.freeze

    # Parse date and time strings into a DateTime object
    def self.parse_datetime(date_str, time_str)
      # Basic sanity check: ensure input strings contain digits before parsing
      return nil unless date_str&.match?(/\d/) && time_str&.match?(/\d/)

      DateTime.parse("#{date_str} #{time_str}")
    rescue Date::Error
      nil
    end

    # Parse a single WhatsApp export line
    # Example input: "[02/05/25, 14:30:15] Alice: Hello"
    def self.parse_whatsapp_line(line)
      pattern = %r{\[(\d{2})/(\d{2})/(\d{2}), (\d{2}):(\d{2}):(\d{2})\] (.*?): (.+)}
      match = pattern.match(line)
      return nil unless match

      day, month, year_short, hh, mm, ss, sender, content = match.captures
      year = "20#{year_short}"
      timestamp = DateTime.parse("#{year}-#{month}-#{day}T#{hh}:#{mm}:#{ss}")
      WhatsAppMessage.new(timestamp: timestamp, sender: sender.strip, content: content.strip)
    rescue ArgumentError
      nil
    end

    # Analyzer class to process messages
    class Analyzer
      attr_reader :sender_shift

      def initialize
        @sender_shift = Hash.new(0)
      end

      def analyze_messages(messages)
        messages.filter_map { |msg| process_message(msg) }
      end

      private

      def process_message(msg)
        text = msg.content
        PATTERNS.each do |type, regex|
          match = regex.match(text)
          next unless match

          groups = match.captures

          # Handle toilet shift setting
          if type == :toilet_set_shift
            begin
              shift = Integer(groups[0])
              @sender_shift[msg.sender] = shift
              return {
                sender: msg.sender,
                message_timestamp: msg.timestamp,
                type: type,
                shift: shift,
                status: :ok
              }
            rescue ArgumentError
              return {
                sender: msg.sender,
                message_timestamp: msg.timestamp,
                original_message: text,
                type: :toilet_set_shift_invalid_number,
                status: :error
              }
            end
          end

          # Handle poop events
          begin
            shift, poop_time = extract_poop_info(type, groups, msg)

            if poop_time.nil?
              status = :error
              details = :invalid_datetime_format
            else
              status = compute_status(poop_time, msg.timestamp)
              details = nil
            end

            result = {
              sender: msg.sender,
              message_timestamp: msg.timestamp,
              original_message: text,
              type: type,
              shift: shift,
              poop_time: poop_time,
              status: status
            }
            result[:error_details] = details if details
            return result
          rescue ArgumentError, TypeError
            return {
              sender: msg.sender,
              message_timestamp: msg.timestamp,
              original_message: text,
              type: :"#{type}_processing_error",
              status: :error
            }
          end
        end

        # Handle messages with emojis but not matching patterns
        if text.include?("💩")
          return {
            sender: msg.sender,
            message_timestamp: msg.timestamp,
            original_message: text,
            type: :unrecognized_poop_emoji,
            status: :error
          }
        end

        if text.include?("🚽")
          return {
            sender: msg.sender,
            message_timestamp: msg.timestamp,
            original_message: text,
            type: :unrecognized_toilet_emoji,
            status: :error
          }
        end

        nil
      end

      def extract_poop_info(type, groups, msg)
        current_sender_shift = @sender_shift[msg.sender]

        case type
        when :poop_live
          [current_sender_shift, msg.timestamp]
        when :poop_live_shift
          shift = Integer(groups[0])
          [shift, msg.timestamp]
        when :poop_past
          poop_dt = Parser.parse_datetime(groups[0], groups[1])
          [current_sender_shift, poop_dt]
        when :poop_past_shift
          shift = Integer(groups[0])
          poop_dt = Parser.parse_datetime(groups[1], groups[2])
          [shift, poop_dt]
        else
          [0, nil]
        end
      end

      def compute_status(poop_time, message_timestamp)
        return :error unless poop_time.is_a?(DateTime)

        # Calculate difference in days
        time_difference_days = message_timestamp - poop_time

        time_difference_days > 30 ? :alert : :ok
      end
    end

    # Main execution logic called by CLI
    def self.run(input_file, output_file)
      # Read input file
      lines = File.readlines(input_file, chomp: true, encoding: "UTF-8")

      # Parse messages
      messages = lines.filter_map { |line| parse_whatsapp_line(line) }

      # Analyze messages
      analyzer = Analyzer.new
      results = analyzer.analyze_messages(messages)

      # Print summary
      puts "Processed #{messages.count} valid messages, found #{results.count} relevant records."

      # Custom JSON conversion for DateTime and Symbols
      json_results = results.map do |record|
        record.transform_values do |value|
          case value
          when DateTime
            value.strftime("%Y-%m-%dT%H:%M:%S")
          when Symbol
            value.to_s
          else
            value
          end
        end
      end

      # Store results as JSON
      File.write(output_file, JSON.pretty_generate(json_results))

      puts "Results saved to #{output_file}"
      0
    rescue Errno::ENOENT
      warn "Error: Input file not found: #{input_file}"
      1
    rescue StandardError => e
      warn "An unexpected error occurred: #{e.message}"
      warn e.backtrace.join("\n")
      1
    end
  end
end
