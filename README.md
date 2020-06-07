

----------
[![Gem Version](https://badge.fury.io/rb/rbhint.svg)](https://badge.fury.io/rb/rbhint)
[![CircleCI Status](https://circleci.com/gh/zspencer/rbhint/tree/development.svg?style=svg)](https://circleci.com/gh/zspencer/rbhint/tree/development)
[![Actions Status](https://github.com/zspencer/rbhint/workflows/CI/badge.svg?branch=development)](https://github.com/zspencer/rbhint/actions?query=workflow%3ACI)
[![Coverage Status](https://api.codeclimate.com/v1/badges/ad6e76460499c8c99697/test_coverage)](https://codeclimate.com/github/zspencer/rbhint)
[![Code Climate](https://codeclimate.com/github/zspencer/rbhint/badges/gpa.svg)](https://codeclimate.com/github/zspencer/rbhint)
[![Inline docs](https://inch-ci.org/github/zspencer/rbhint.svg)](https://inch-ci.org/github/zspencer/rbhint)
[![SemVer](https://api.dependabot.com/badges/compatibility_score?dependency-name=rbhint&package-manager=bundler&version-scheme=semver)](https://dependabot.com/compatibility-score.html?dependency-name=rbhint&package-manager=bundler&version-scheme=semver)

> I'm no longer accepting the things I cannot change... I'm changing the things I cannot accept. <br/>
> -- Angela Davis

**RbHint** is a Ruby static code analyzer (a.k.a. `linter`) and code formatter. Out of the box it
will encourage many of the guidelines outlined in the community [Ruby Style
Guide](https://rubystyle.guide). Apart from reporting the problems discovered in your code,
RbHint can also automatically fix many of them you.

RbHint is extremely flexible and most aspects of its behavior can be tweaked via various
[configuration options](https://github.com/zspencer/rbhint/blob/development/config/default.yml).

## Installation

**RbHint**'s installation is pretty standard:

```sh
$ gem install rbhint
```

If you'd rather install RbHint using `bundler`, add a line for it in your `Gemfile` (but set the `require` option to `false`, as it is a standalone tool):

```rb
gem 'rbhint', require: false
```

RbHint's development is moving at a very rapid pace and there are
often backward-incompatible changes between minor releases (since we
haven't reached version 1.0 yet). To prevent an unwanted RbHint update you
might want to use a conservative version lock in your `Gemfile`:

```rb
gem 'rbhint', '~> 0.85.0', require: false
```

## Quickstart

Just type `rbhint` in a Ruby project's folder and watch the magic happen.

```
$ cd my/cool/ruby/project
$ rbhint
```

## Documentation

RbHint is a feature-for-feature compatible adaptation of RuboCop, with a kindler, gentler approach to encouragingg change. You can read more about how to use RbHint by reading [RuboCop's official docs](https://docs.rubocop.org).

## Compatibility

RbHint supports the following Ruby implementations:

* MRI 2.4+
* JRuby 9.2+

See [compatibility](https://docs.rubocop.org/rubocop/compatibility.html) for further details.

## Team

Currently, `rbhint` is maintained by [Zee Spencer](https://github.com/zspencer).
Other contributions would be appreciated.

Here's a list of RbHint's historic developers:

* [Bozhidar Batsov](https://github.com/bbatsov) (author & head maintainer)
* [Jonas Arvidsson](https://github.com/jonas054)
* [Yuji Nakayama](https://github.com/yujinakayama) (retired)
* [Evgeni Dzhelyov](https://github.com/edzhelyov) (retired)
* [Ted Johansson](https://github.com/drenmi)
* [Masataka Kuwabara](https://github.com/pocke)
* [Koichi Ito](https://github.com/koic)
* [Maxim Krizhanovski](https://github.com/darhazer)
* [Benjamin Quorning](https://github.com/bquorning)
* [Marc-André Lafortune](https://github.com/marcandre)


## Contributors

Here's a [list](https://github.com/zspencer/rbhint/graphs/contributors) of
all the people who have contributed to the development of RbHint.

I'm extremely grateful to each and every one of them!

If you'd like to contribute to RbHint, please take the time to go
through our short
[contribution guidelines](CONTRIBUTING.md).

Converting more of the Ruby Style Guide into RbHint norms is our top
priority right now. Writing a new norm is a great way to dive into RbHint!

Of course, bug reports and suggestions for improvements are always
welcome. GitHub pull requests are even better! :-)

## Changelog

RbHint's changelog is available [here](CHANGELOG.md).

## Copyright

Copyright (c) 2012-2020 Bozhidar Batsov, 2020 Zee Spencer. See [LICENSE.txt](LICENSE.txt) for
further details.
