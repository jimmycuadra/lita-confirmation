# lita-confirmation

[![RubyGems](https://img.shields.io/gem/v/lita-confirmation.svg)](https://rubygems.org/gems/lita-confirmation)
[![Build Status](https://img.shields.io/travis/jimmycuadra/lita-confirmation/master.svg)](https://travis-ci.org/jimmycuadra/lita-confirmation)
[![Code Climate](https://img.shields.io/codeclimate/github/jimmycuadra/lita-confirmation.svg)](https://codeclimate.com/github/jimmycuadra/lita-confirmation)
[![Coverage Status](https://img.shields.io/coveralls/jimmycuadra/lita-confirmation/master.svg)](https://coveralls.io/r/jimmycuadra/lita-confirmation)

**lita-confirmation** is an extension for [Lita](https://www.lita.io/) that allows handler routes to require "confirmation" before being triggered. Confirmation consists of a second message sent to the robot with a confirmation code.

## Installation

Add lita-confirmation to your Lita plugin's gemspec:

``` ruby
spec.add_runtime_dependency "lita-confirmation"
```

## Usage

### Basic confirmation

For basic confirmation, simply set the `:confirmation` option to true when defining a route.

``` ruby
route /danger/, :danger, command: true, confirmation: true
```

This will result in the following behavior:

```
Alice: Lita, danger
Lita: This command requires confirmation. To confirm, send the command "confirm 636f308"
Alice: Lita, confirm 636f308
Lita: Dangerous command executed!
```

### Customized confirmation

There are a few different options that can be supplied to customize the way the confirmation behaves. To supply one or more options, pass a hash as the value for the `:confirmation` option instead of just a boolean.

#### allow_self

By default, the same user who initially triggered the command can confirm it. If you want to make it even harder to trigger a command accidentally, you can require that another user send the confirmation command by setting the `:allow_self` option to false.

``` ruby
route /danger/, :danger, command: true, confirmation: { allow_self: false }
```

```
Alice: Lita, danger
Lita: This command requires confirmation. To confirm, send the command "confirm 636f308"
Alice: Lita, confirm 636f308
Lita: Confirmation 636f308 must come from a different user.
Bob: Lita, confirm 636f308
Lita: Dangerous command executed!
```

#### restrict_to

If you want to require that the confirming user be a member of a particular authorization group, use the `:restrict_to` option. The value can be either a string, a symbol, or an array or strings/symbols.

``` ruby
route /danger/, :danger, command: true, confirmation: { restrict_to: :managers }
```

```
Alice: Lita, danger
Lita: This command requires confirmation. To confirm, send the command "confirm 636f308"
Alice: Lita, confirm 636f308
Lita: Confirmation 636f308 must come from a user in one of the following authorization groups: managers
Manager: Lita, confirm 636f308
Lita: Dangerous command executed!
```

#### expire_after

By default, a confirmation must be made within one minute of the original command. After the expiry period, the original command must be sent again, and a new confirmation code will be generated. To change the length of the expiry, set the `:expire_after` value to an integer or string number of seconds.

``` ruby
route /danger/, :danger, command: true, confirmation: { expire_after: 10 }
```

```
Alice: Lita, danger
Lita: This command requires confirmation. To confirm, send the command "confirm 636f308"
Alice: Waiting 15 seconds...
Alice: Lita, confirm 636f308
Lita: 636f308 is not a valid confirmation code. It may have expired. Please run the original command again.
```

## License

[MIT](http://opensource.org/licenses/MIT)
