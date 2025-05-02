# frozen_string_literal: true

require "thor"
require_relative "parser"

module LooParser
  # Defines the command-line interface commands
  class CLI < Thor
    package_name "LooParser"

    desc "parse [INPUT_FILE] [OUTPUT_FILE]", "Parse WhatsApp chat export and save results."
    long_desc <<-LONGDESC
      Parses a WhatsApp chat export file (.txt) to find 💩 and 🚽 messages,
      analyzing bathroom usage patterns.

      Defaults:
        INPUT_FILE: whatsapp_chat.txt
        OUTPUT_FILE: poop_results.json
    LONGDESC
    def parse(input_file = "whatsapp_chat.txt", output_file = "poop_results.json")
      puts "Starting analysis of #{input_file}..."
      exit_code = LooParser::Parser.run(input_file, output_file)
      exit(exit_code)
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit(1)
    end

    desc "version", "Show LooParser version"
    def version
      puts LooParser::VERSION
    end
  end
end
