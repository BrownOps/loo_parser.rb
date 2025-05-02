# Loo Parser (Ruby Gem)

[![Test & Lint](https://github.com/BrownOps/loo_parser.rb/actions/workflows/test.yml/badge.svg)](https://github.com/BrownOps/loo_parser.rb/actions/workflows/test.yml)

A Ruby tool for parsing WhatsApp chat exports to track and analyze bathroom usage patterns through specific emoji-based messages.

## Overview

Loo Parser processes WhatsApp chat logs to extract, track, and analyze messages containing 💩 and 🚽 emojis according to a specific syntax. It helps keep track of bathroom usage over time by different chat participants, including timing and frequency analysis.

## Features

- Parse WhatsApp chat exports (.txt format)
- Recognize multiple message formats for tracking events:
  - Live events (happening now): `💩`
  - Past events (specific time): `💩 YYYY-MM-DD HH:MM`
  - Events with time shift: `💩 +N` or `💩 -N`
  - Setting default time shift: `🚽 +N` or `🚽 -N`
- Track per-user bathroom usage patterns (via default shift)
- Detect and alert on unusual timing patterns (>30 days between event and message)
- Export structured data as JSON for further analysis

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'loo_parser'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install loo_parser
```

## Usage

After installation, you can run the parser from your command line:

```bash
loo-parser parse [INPUT_FILE] [OUTPUT_FILE]
```

For example, using a sample file:

```bash
loo-parser parse whatsapp_chat_example.txt example_results.json
```

This will parse the `whatsapp_chat_example.txt` file and save the extracted events to `example_results.json`.

If no files are specified, it will default to `whatsapp_chat.txt` for input and `poop_results.json` for output.

### Message Format Examples

The parser recognizes the following message formats within the WhatsApp export:

```
[DD/MM/YY, HH:MM:SS] Alice: 💩                         # Current poop event
[DD/MM/YY, HH:MM:SS] Bob: 💩 2023-04-15 08:30          # Past poop event
[DD/MM/YY, HH:MM:SS] Charlie: 💩 +2                    # Current poop with +2 shift
[DD/MM/YY, HH:MM:SS] Dave: 💩 -1 2023-04-10 19:45      # Past poop with -1 shift
[DD/MM/YY, HH:MM:SS] Eve: 🚽 +3                        # Set default shift to +3 for Eve
```

### Output Format

The parser outputs JSON data in the following format (datetimes are ISO8601 strings, statuses/types are strings):

```json
[
  {
    "sender": "Alice",
    "message_timestamp": "2023-05-01T10:05:00+00:00",
    "original_message": "💩",
    "type": "poop_live",
    "shift": 0,
    "poop_time": "2023-05-01T10:05:00+00:00",
    "status": "ok"
  },
  {
    "sender": "Bob",
    "message_timestamp": "2023-05-01T10:07:00+00:00",
    "original_message": "💩 2023-04-30 09:00",
    "type": "poop_past",
    "shift": 0,
    "poop_time": "2023-04-30T09:00:00+00:00",
    "status": "ok"
  },
  {
    "sender": "Dave",
    "message_timestamp": "2023-06-15T10:00:00+00:00",
    "original_message": "💩 2023-04-10 09:00",
    "type": "poop_past",
    "shift": 0,
    "poop_time": "2023-04-10T09:00:00+00:00",
    "status": "alert"
  }
]
```

Status values can be:

- `ok`: Normal event (reported within 30 days of occurrence)
- `alert`: Event reported more than 30 days after occurrence
- `error`: Invalid format or parsing error (includes specific error types)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running Tests

```bash
bundle exec rake spec
# or
bundle exec rspec
```

### Linting

```bash
bundle exec rake rubocop
# or
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/BrownOps/loo_parser.rb](https://github.com/BrownOps/loo_parser.rb).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
