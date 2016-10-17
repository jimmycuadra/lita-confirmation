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
Lita: This command requires confirmation. To confirm, send the command: Lita confirm 636f308
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
Lita: This command requires confirmation. To confirm, send the command: Lita confirm 636f308
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
Lita: This command requires confirmation. To confirm, send the command: Lita confirm 636f308
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
Lita: This command requires confirmation. To confirm, send the command: Lita confirm 636f308
Alice: Waiting 15 seconds...
Alice: Lita, confirm 636f308
Lita: 636f308 is not a valid confirmation code. It may have expired. Please run the original command again.
```

### Two Factor Confirmation

If the basic confirmation is just a "sanity check" (are you sure you want to do this?), and a confirmation
requiring another group or another user is much more critical ("we want another human to approve this"), then
two factor confirmation (2FC) is somewhere in the middle ("we want to be really sure it's actually you") and also
takes some of the verification trust away from Slack. Two factor confirmation works by setting up a TOTP
(time-based one time password) for each user and verifying it.

When 2FC is used, a TOTP must be entered in addition to the confirmation code:

```
Alice: Lita, danger
Lita: This command requires confirmation. To confirm, send the command: Lita confirm 636f308 YOUR_ONE_TIME_PASSWORD
Alice: Opens Google Authenticator on her phone, looks up the current password
Alice: Lita, confirm 636f308 682645
Lita: Dangerous command executed!
```

The default behavior is not to require 2FC on any routes. This global setting is configurable:

``` ruby
config.handlers.confirmation.twofactor_default = :allow
```

There are three choices:

1. `block` - two factor confirmation is not used
2. `allow` - if the user is enrolled into 2FC, it is used; otherwise, regular confirmation is used.
3. `require` - 2FC is mandatory. If the user is not enrolled, they will be asked to enroll first.

The default can be overridden for any route:

``` ruby
route /danger/, :danger, command: true, confirmation: { twofactor: :allow }
```

To enroll, a user provides an e-mail address, and receives an e-mail with the secret for the TOTP algorithm
and a QR code in an image that contains the same settings in a format readable by many popular TOTP apps.

```
Alice: Lita, confirm 2fa enroll alice@corp.io
Lita: You are now enrolled into two factor confirmation. Check your email inbox for details.

...
Subject: Lita two-factor confirmation enrollment

Hi Alice,

You are now enrolled into two factor confirmation. Your secret code is yczja4wk5mjy4koe.
Use the code with any TOTP application such as Google Authenticator
to generate one-time passwords. Thank you for improving security!

Many applications (including Google Authenticator) can import the secret
from the QR code attached to this message.
```

Three configuration settings are used for configuring e-mail:

- `smtp_host`, default `localhost`
- `smtp_port`, default `25`
- `from_email`, the From address for the enrollment e-mail.

Lita administrators and members of the `confirmation_admin` group can remove
2FC registration from other users. There is an "insecure" mode, disabled by
default, that allows users to remove themselves from 2FC and to enroll multiple
times. This can be useful when evaluating whether the benefits of 2FC outweigh
the inconvenience of having to consult another device for the password, and while
migrating from plain confirmation to 2FC. The config value is `twofactor_secure`
and the default is `true`.

## License

[MIT](http://opensource.org/licenses/MIT)
