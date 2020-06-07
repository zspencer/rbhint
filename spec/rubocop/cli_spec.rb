# frozen_string_literal: true

require 'timeout'

RSpec.describe RuboCop::CLI, :isolated_environment do
  include_context 'cli spec behavior'

  subject(:cli) { described_class.new }

  context 'when interrupted' do
    it 'returns 130' do
      allow_any_instance_of(RuboCop::Runner)
        .to receive(:aborting?).and_return(true)
      create_empty_file('example.rb')
      expect(cli.run(['example.rb'])).to eq(130)
    end
  end

  context 'when given a file/directory that is not under the current dir' do
    shared_examples 'checks Rakefile' do
      it 'checks a Rakefile but Style/FileName does not report' do
        create_file('Rakefile', <<~RUBY)
          # frozen_string_literal: true

          x = 1
        RUBY
        create_empty_file('other/empty')
        RuboCop::PathUtil.chdir('other') do
          expect(cli.run(['--format', 'simple', checked_path])).to eq(1)
        end
        expect($stdout.string).to eq(<<~RESULT)
          == #{abs('Rakefile')} ==
          W:  3:  1: Lint/UselessAssignment: Useless assignment to variable - x.

          1 file inspected, 1 offense detected
        RESULT
      end
    end

    context 'and the directory is absolute' do
      let(:checked_path) { abs('..') }

      include_examples 'checks Rakefile'
    end

    context 'and the directory is relative' do
      let(:checked_path) { '..' }

      include_examples 'checks Rakefile'
    end

    context 'and the Rakefile path is absolute' do
      let(:checked_path) { abs('../Rakefile') }

      include_examples 'checks Rakefile'
    end

    context 'and the Rakefile path is relative' do
      let(:checked_path) { '../Rakefile' }

      include_examples 'checks Rakefile'
    end
  end

  context 'when lines end with CR+LF' do
    it 'reports an offense' do
      create_file('example.rb', <<~RUBY)
        x = 0\r
        puts x\r
      RUBY
      # Make Style/EndOfLine give same output regardless of platform.
      create_file('.rubocop.yml', <<~YAML)
        EndOfLine:
          EnforcedStyle: lf
      YAML
      result = cli.run(['--format', 'simple', 'example.rb'])
      expect(result).to eq(1)
      expect($stdout.string)
        .to eq(<<~RESULT)
          == example.rb ==
          C:  1:  1: Layout/EndOfLine: Carriage return character detected.
          C:  1:  1: Style/FrozenStringLiteralComment: Missing frozen string literal comment.

          1 file inspected, 2 offenses detected
      RESULT
      expect($stderr.string).to eq(<<~RESULT)
        #{abs('.rubocop.yml')}: Warning: no department given for EndOfLine.
      RESULT
    end
  end

  context 'when checking a correct file' do
    it 'returns 0' do
      create_file('example.rb', <<~RUBY)
        # frozen_string_literal: true

        x = 0
        puts x
      RUBY
      expect(cli.run(['--format', 'simple', 'example.rb'])).to eq(0)
      expect($stdout.string)
        .to eq(<<~RESULT)

          1 file inspected, no offenses detected
      RESULT
    end

    context 'when super is used with a block' do
      it 'still returns 0' do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true

          # this is a class
          class Thing
            def super_with_block
              super { |response| }
            end

            def and_with_args
              super(arg1, arg2) { |response| }
            end
          end
        RUBY
        create_file('.rubocop.yml', <<~YAML)
          Lint/UnusedBlockArgument:
            IgnoreEmptyBlocks: true
        YAML
        expect(cli.run(['--format', 'simple', 'example.rb'])).to eq(0)
        expect($stdout.string)
          .to eq(<<~RESULT)

            1 file inspected, no offenses detected
        RESULT
      end
    end
  end

  it 'checks a given file with faults and returns 1' do
    create_file('example.rb', [
                  '# frozen_string_literal: true', '', 'x = 0 ', 'puts x'
                ])
    expect(cli.run(['--format', 'simple', 'example.rb'])).to eq(1)
    expect($stdout.string)
      .to eq <<~RESULT
        == example.rb ==
        C:  3:  6: Layout/TrailingWhitespace: Trailing whitespace detected.

        1 file inspected, 1 offense detected
    RESULT
  end

  it 'registers an offense for a syntax error' do
    create_file('example.rb', ['class Test', 'en'])
    expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
    expect($stdout.string)
      .to eq(["#{abs('example.rb')}:3:1: E: Lint/Syntax: unexpected " \
              'token $end (Using Ruby 2.4 parser; configure using ' \
              '`TargetRubyVersion` parameter, under `AllCops`)',
              ''].join("\n"))
  end

  it 'registers an offense for Parser warnings' do
    create_file('example.rb', [
                  '# frozen_string_literal: true',
                  '',
                  'puts *test',
                  'if a then b else c end'
                ])
    aggregate_failures('CLI output') do
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
      expect($stdout.string)
        .to eq(["#{abs('example.rb')}:3:6: W: Lint/AmbiguousOperator: " \
                'Ambiguous splat operator. Parenthesize the method arguments ' \
                "if it's surely a splat operator, or add a whitespace to the " \
                'right of the `*` if it should be a multiplication.',
                "#{abs('example.rb')}:4:1: C: Style/OneLineConditional: " \
                'Favor the ternary operator (`?:`) over `if/then/else/end` ' \
                'constructs.',
                ''].join("\n"))
    end
  end

  it 'can process a file with an invalid UTF-8 byte sequence' do
    create_file('example.rb', ["# #{'f9'.hex.chr}#{'29'.hex.chr}"])
    expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
    expect($stdout.string)
      .to eq(<<~RESULT)
        #{abs('example.rb')}:1:1: F: Lint/Syntax: Invalid byte sequence in utf-8.
    RESULT
  end

  context 'when errors are raised while processing files due to bugs' do
    let(:errors) do
      ['An error occurred while Encoding cop was inspecting file.rb.']
    end

    before do
      allow_any_instance_of(RuboCop::Runner)
        .to receive(:errors).and_return(errors)
    end

    it 'displays an error message to stderr' do
      cli.run([])
      expect($stderr.string)
        .to include('1 error occurred:').and include(errors.first)
    end
  end

  describe 'rubocop:disable comment' do
    it 'can disable all cops in a code section' do
      src = ['# rubocop:disable all',
             '#' * 130,
             'x(123456)',
             'y("123")',
             'def func',
             '  # rubocop: enable Layout/LineLength,Style/StringLiterals',
             '  ' + '#' * 130,
             '  x(123456)',
             '  y("123")',
             'end']
      create_file('example.rb', src)
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
      # all cops were disabled, then 2 were enabled again, so we
      # should get 2 offenses reported.
      expect($stdout.string).to eq(<<~RESULT)
        #{abs('example.rb')}:7:121: C: Layout/LineLength: Line is too long. [132/120]
        #{abs('example.rb')}:9:5: C: Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.
      RESULT
    end

    describe 'Specify `--init` option to `rubocop` command' do
      context 'when .rubocop.yml does not exist' do
        it 'generate a .rubocop.yml file' do
          expect(cli.run(['--init'])).to eq(0)
          expect($stdout.string).to start_with('Writing new .rubocop.yml to')
          expect(IO.read('.rubocop.yml')).to eq(<<~YAML)
            # The behavior of RuboCop can be controlled via the .rubocop.yml
            # configuration file. It makes it possible to enable/disable
            # certain cops (checks) and to alter their behavior if they accept
            # any parameters. The file can be placed either in your home
            # directory or in some project directory.
            #
            # RuboCop will start looking for the configuration file in the directory
            # where the inspected file is and continue its way up to the root directory.
            #
            # See https://github.com/zspencer/rbhint/blob/development/manual/configuration.md
          YAML
        end
      end

      context 'when .rubocop.yml already exists' do
        it 'fails with an error message' do
          create_empty_file('.rubocop.yml')

          expect(cli.run(['--init'])).to eq(2)
          expect($stderr.string).to start_with('.rubocop.yml already exists at')
        end
      end
    end

    context 'when --auto-correct is given' do
      it 'does not trigger RedundantCopDisableDirective due to ' \
         'lines moving around' do
        src = ['a = 1 # rubocop:disable Lint/UselessAssignment']
        create_file('example.rb', src)
        create_file('.rubocop.yml', <<~YAML)
          Style/FrozenStringLiteralComment:
            Enabled: true
            EnforcedStyle: always
          Layout/EmptyLineAfterMagicComment:
            Enabled: false
        YAML
        expect(cli.run(['--format', 'offenses', '-a', 'example.rb'])).to eq(0)
        expect($stdout.string).to eq(<<~RESULT)

          1  Style/FrozenStringLiteralComment
          --
          1  Total

        RESULT
        expect(IO.read('example.rb'))
          .to eq(<<~RUBY)
            # frozen_string_literal: true
            a = 1 # rubocop:disable Lint/UselessAssignment
        RUBY
      end
    end

    it 'can disable selected cops in a code section' do
      create_file('example.rb',
                  ['# frozen_string_literal: true',
                   '',
                   '# rubocop:disable Style/LineLength,' \
                   'Style/NumericLiterals,Style/StringLiterals',
                   '#' * 130,
                   'x(123456)',
                   'y("123")',
                   'def func',
                   '  # rubocop: enable Layout/LineLength, ' \
                   'Style/StringLiterals',
                   '  ' + '#' * 130,
                   '  x(123456)',
                   '  y("123")',
                   '  # rubocop: enable Style/NumericLiterals',
                   'end'])
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
      expect($stderr.string)
        .to eq(['example.rb: Style/LineLength has the wrong ' \
                'namespace - should be Layout',
                ''].join("\n"))
      # 2 real cops were disabled, and 1 that was incorrect
      # 2 real cops was enabled, but only 1 had been disabled correctly
      expect($stdout.string).to eq(<<~RESULT)
        #{abs('example.rb')}:8:21: W: Lint/RedundantCopEnableDirective: Unnecessary enabling of Layout/LineLength.
        #{abs('example.rb')}:9:121: C: Layout/LineLength: Line is too long. [132/120]
        #{abs('example.rb')}:11:5: C: Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.
      RESULT
    end

    it 'can disable all cops on a single line' do
      create_file('example.rb', 'y("123", 123456) # rubocop:disable all')
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(0)
      expect($stdout.string.empty?).to be(true)
    end

    it 'can disable selected cops on a single line' do
      create_file('example.rb',
                  ['# frozen_string_literal: true',
                   '',
                   'a' * 130 + ' # rubocop:disable Layout/LineLength',
                   '#' * 130,
                   'y("123", 123456) # rubocop:disable Style/StringLiterals,' \
                   'Style/NumericLiterals'])
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
      expect($stdout.string)
        .to eq(<<~RESULT)
          #{abs('example.rb')}:4:121: C: Layout/LineLength: Line is too long. [130/120]
      RESULT
    end

    context 'without using namespace' do
      it 'can disable selected cops on a single line but prints a warning' do
        create_file('example.rb',
                    ['# frozen_string_literal: true',
                     '',
                     'a' * 130 + ' # rubocop:disable LineLength',
                     '#' * 130,
                     'y("123") # rubocop:disable StringLiterals'])
        expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
        expect($stderr.string).to eq(<<~OUTPUT)
          #{abs('example.rb')}: Warning: no department given for LineLength. Run `rubocop -a --only Migration/DepartmentName` to fix.
          #{abs('example.rb')}: Warning: no department given for StringLiterals. Run `rubocop -a --only Migration/DepartmentName` to fix.
        OUTPUT
        expect($stdout.string)
          .to eq(<<~RESULT)
            #{abs('example.rb')}:3:150: C: Migration/DepartmentName: Department name is missing.
            #{abs('example.rb')}:4:121: C: Layout/LineLength: Line is too long. [130/120]
            #{abs('example.rb')}:5:28: C: Migration/DepartmentName: Department name is missing.
        RESULT
      end
    end

    context 'when not necessary' do
      it 'causes an offense to be reported' do
        create_file('example.rb',
                    ['# frozen_string_literal: true',
                     '',
                     '#' * 130,
                     '# rubocop:disable all',
                     'a' * 10 + ' ' \
                     '# rubocop:disable Layout/LineLength,Metrics/ClassLength',
                     'y(123) # rubocop:disable all',
                     '# rubocop:enable all'])
        expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(1)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~RESULT)
          #{abs('example.rb')}:3:121: C: Layout/LineLength: Line is too long. [130/120]
          #{abs('example.rb')}:4:1: W: Lint/RedundantCopDisableDirective: Unnecessary disabling of all cops.
          #{abs('example.rb')}:5:12: W: Lint/RedundantCopDisableDirective: Unnecessary disabling of `Layout/LineLength`, `Metrics/ClassLength`.
          #{abs('example.rb')}:6:8: W: Lint/RedundantCopDisableDirective: Unnecessary disabling of all cops.
        RESULT
      end

      context 'and there are no other offenses' do
        it 'exits with error code' do
          create_file('example.rb', 'a' * 10 + ' # rubocop:disable LineLength')
          expect(cli.run(['example.rb'])).to eq(1)
        end
      end

      shared_examples 'RedundantCopDisableDirective not run' do |state, config|
        context "and RedundantCopDisableDirective is #{state}" do
          it 'does not report RedundantCopDisableDirective offenses' do
            create_file('example.rb',
                        ['# frozen_string_literal: true',
                         '',
                         '#' * 130,
                         '# rubocop:disable all',
                         'a' * 10 + ' # rubocop:disable LineLength,ClassLength',
                         'y(123) # rubocop:disable all'])
            create_file('.rubocop.yml', config)
            expect(cli.run(['--format', 'emacs'])).to eq(1)
            expect($stderr.string).to eq(<<~OUTPUT)
              #{abs('example.rb')}: Warning: no department given for LineLength. Run `rubocop -a --only Migration/DepartmentName` to fix.
              #{abs('example.rb')}: Warning: no department given for ClassLength. Run `rubocop -a --only Migration/DepartmentName` to fix.
            OUTPUT
            expect($stdout.string)
              .to eq(<<~RESULT)
                #{abs('example.rb')}:3:121: C: Layout/LineLength: Line is too long. [130/120]
              RESULT
          end
        end
      end

      include_examples 'RedundantCopDisableDirective not run',
                       'individually disabled', <<~YAML
                         Lint/RedundantCopDisableDirective:
                           Enabled: false
                       YAML
      include_examples 'RedundantCopDisableDirective not run',
                       'individually excluded', <<~YAML
                         Lint/RedundantCopDisableDirective:
                           Exclude:
                             - example.rb
                       YAML
      include_examples 'RedundantCopDisableDirective not run',
                       'disabled through department', <<~YAML
                         Lint:
                           Enabled: false
                       YAML
    end
  end

  it 'finds a file with no .rb extension but has a shebang line' do
    allow_any_instance_of(File::Stat)
      .to receive(:executable?).and_return(true)
    create_file('example', ['#!/usr/bin/env ruby', 'x = 0', 'puts x'])
    create_file('.rubocop.yml', <<~YAML)
      Style/FrozenStringLiteralComment:
        Enabled: false
    YAML
    expect(cli.run(%w[--format simple])).to eq(0)
    expect($stdout.string)
      .to eq(['', '1 file inspected, no offenses detected', ''].join("\n"))
  end

  it 'does not register any offenses for an empty file' do
    create_empty_file('example.rb')
    expect(cli.run(%w[--format simple])).to eq(0)
    expect($stdout.string)
      .to eq(['', '1 file inspected, no offenses detected', ''].join("\n"))
  end

  describe 'style guide only usage' do
    context 'via the cli option' do
      describe '--only-guide-cops' do
        it 'skips cops that have no link to a style guide' do
          create_file('example.rb', 'raise')
          create_file('.rubocop.yml', <<~YAML)
            Layout/LineLength:
              Enabled: true
              StyleGuide: ~
              Max: 2
          YAML

          expect(cli.run(['--format', 'simple', '--only-guide-cops',
                          'example.rb'])).to eq(0)
        end

        it 'runs cops for rules that link to a style guide' do
          create_file('example.rb', 'raise')
          create_file('.rubocop.yml', <<~YAML)
            Layout/LineLength:
              Enabled: true
              StyleGuide: "http://an.example/url"
              Max: 2
          YAML

          expect(cli.run(['--format', 'simple', '--only-guide-cops',
                          'example.rb'])).to eq(1)

          expect($stdout.string)
            .to eq(<<~RESULT)
              == example.rb ==
              C:  1:  3: Layout/LineLength: Line is too long. [5/2]

              1 file inspected, 1 offense detected
            RESULT
        end

        it 'overrides configuration of AllCops/StyleGuideCopsOnly' do
          create_file('example.rb', 'raise')
          create_file('.rubocop.yml', <<~YAML)
            AllCops:
              StyleGuideCopsOnly: false
            Layout/LineLength:
              Enabled: true
              StyleGuide: ~
              Max: 2
          YAML

          expect(cli.run(['--format', 'simple', '--only-guide-cops',
                          'example.rb'])).to eq(0)
        end
      end
    end

    context 'via the config' do
      before do
        create_file('example.rb', <<~RUBY)
          if foo and bar
            do_something
          end
        RUBY
        create_file('.rubocop.yml', <<~YAML)
          AllCops:
            StyleGuideCopsOnly: #{guide_cops_only}
            DisabledByDefault: #{disabled_by_default}
          Layout/LineLength:
            Enabled: true
            StyleGuide: ~
            Max: 2
          Style/FrozenStringLiteralComment:
            Enabled: false
        YAML
      end

      describe 'AllCops/StyleGuideCopsOnly' do
        let(:disabled_by_default) { 'false' }

        context 'when it is true' do
          let(:guide_cops_only) { 'true' }

          it 'skips cops that have no link to a style guide' do
            expect(cli.run(['--format', 'offenses', 'example.rb'])).to eq(1)

            expect($stdout.string).to eq(<<~RESULT)

              1  Style/AndOr
              --
              1  Total

            RESULT
          end
        end

        context 'when it is false' do
          let(:guide_cops_only) { 'false' }

          it 'runs cops for rules regardless of any link to the style guide' do
            expect(cli.run(['--format', 'offenses', 'example.rb'])).to eq(1)

            expect($stdout.string).to eq(<<~RESULT)

              3  Layout/LineLength
              1  Style/AndOr
              --
              4  Total

            RESULT
          end
        end
      end

      describe 'AllCops/DisabledByDefault' do
        let(:guide_cops_only) { 'false' }

        context 'when it is true' do
          let(:disabled_by_default) { 'true' }

          it 'runs only the cop configured in .rubocop.yml' do
            expect(cli.run(['--format', 'offenses', 'example.rb'])).to eq(1)

            expect($stdout.string).to eq(<<~RESULT)

              3  Layout/LineLength
              --
              3  Total

            RESULT
          end
        end

        context 'when it is false' do
          let(:disabled_by_default) { 'false' }

          it 'runs all cops that are enabled in default configuration' do
            expect(cli.run(['--format', 'offenses', 'example.rb'])).to eq(1)

            expect($stdout.string).to eq(<<~RESULT)

              3  Layout/LineLength
              1  Style/AndOr
              --
              4  Total

            RESULT
          end
        end
      end
    end
  end

  describe 'cops can exclude files based on config' do
    it 'ignores excluded files' do
      create_file('example.rb', 'x = 0')
      create_file('regexp.rb', 'x = 0')
      create_file('exclude_glob.rb', ['#!/usr/bin/env ruby', 'x = 0'])
      create_file('dir/thing.rb', 'x = 0')
      create_file('.rubocop.yml', <<~'YAML')
        Lint/UselessAssignment:
          Exclude:
            - example.rb
            - !ruby/regexp /regexp.rb\z/
            - "exclude_*"
            - "dir/*"
        Style/FrozenStringLiteralComment:
          Enabled: false
      YAML
      allow_any_instance_of(File::Stat)
        .to receive(:executable?).and_return(true)
      expect(cli.run(%w[--format simple])).to eq(0)
      expect($stdout.string)
        .to eq(['', '4 files inspected, no offenses detected',
                ''].join("\n"))
    end
  end

  describe 'configuration from file' do
    before do
      RuboCop::ConfigLoader.default_configuration = nil
    end

    context 'when a value in a hash is overridden with nil' do
      it 'acts as if the key/value pair was removed' do
        create_file('.rubocop.yml', <<~YAML)
          Style/InverseMethods:
            InverseMethods:
              :even?: ~
          Style/CollectionMethods:
            Enabled: true
            PreferredMethods:
              collect: ~
          Style/FrozenStringLiteralComment:
            Enabled: false
        YAML
        create_file('example.rb', 'array.collect { |e| !e.odd? }')
        expect(cli.run([])).to eq(0)
      end
    end

    context 'when configured for indented_internal_methods style ' \
            'indentation' do
      it 'accepts indented_internal_methods style indentation' do
        create_file('.rubocop.yml', <<~YAML)
          Layout/IndentationConsistency:
            EnforcedStyle: indented_internal_methods
          Style/FrozenStringLiteralComment:
            Enabled: false
        YAML
        create_file('example.rb', <<~RUBY)
          # A feline creature
          class Cat
            def meow
              puts('Meow!')
            end

            protected

              def can_we_be_friends?(another_cat)
                some_logic(another_cat)
              end

            private

              def meow_at_3am?
                rand < 0.8
              end
          end
        RUBY
        result = cli.run(%w[--format simple])
        expect($stderr.string).to eq('')
        expect(result).to eq(0)
        expect($stdout.string)
          .to eq(['', '1 file inspected, no offenses detected',
                  ''].join("\n"))
      end

      %w[class module].each do |parent|
        it "registers offense for normal indentation in #{parent}" do
          create_file('.rubocop.yml', <<~YAML)
            Layout/IndentationConsistency:
              EnforcedStyle: indented_internal_methods
            Style/FrozenStringLiteralComment:
              Enabled: false
          YAML
          create_file('example.rb', <<~RUBY)
            # A feline creature
            #{parent} Cat
              def meow
                puts('Meow!')
              end

              protected

              def can_we_be_friends?(another_cat)
                some_logic(another_cat)
              end

              private

              def meow_at_3am?
                rand < 0.8
              end

              def meow_at_4am?
                rand < 0.8
              end
            end
          RUBY
          result = cli.run(%w[--format simple])
          expect($stderr.string).to eq('')
          expect(result).to eq(1)
          expect($stdout.string)
            .to eq(<<~RESULT)
              == example.rb ==
              C:  9:  3: Layout/IndentationWidth: Use 2 (not 0) spaces for indented_internal_methods indentation.
              C: 15:  3: Layout/IndentationWidth: Use 2 (not 0) spaces for indented_internal_methods indentation.

              1 file inspected, 2 offenses detected
          RESULT
        end
      end
    end

    context 'when obsolete MultiSpaceAllowedForOperators param is used' do
      it 'displays a warning' do
        create_file('.rubocop.yml', <<~YAML)
          Layout/SpaceAroundOperators:
            MultiSpaceAllowedForOperators:
              - "="
        YAML
        expect(cli.run([])).to eq(2)
        expect($stderr.string).to include('obsolete parameter ' \
                                          'MultiSpaceAllowedForOperators ' \
                                          '(for Layout/SpaceAroundOperators)' \
                                          ' found')
      end
    end

    context 'when MultilineMethodCallIndentation is used with aligned ' \
            'style and IndentationWidth parameter' do
      it 'fails with an error message' do
        create_file('example.rb', 'puts 1')
        create_file('.rubocop.yml', <<~YAML)
          Layout/MultilineMethodCallIndentation:
            EnforcedStyle: aligned
            IndentationWidth: 1
        YAML
        expect(cli.run(['example.rb'])).to eq(2)
        expect($stderr.string.strip).to eq(
          'Error: The `Layout/MultilineMethodCallIndentation` cop only ' \
          'accepts an `IndentationWidth` configuration parameter when ' \
          '`EnforcedStyle` is `indented`.'
        )
      end
    end

    context 'when MultilineOperationIndentation is used with aligned ' \
            'style and IndentationWidth parameter' do
      it 'fails with an error message' do
        create_file('example.rb', 'puts 1')
        create_file('.rubocop.yml', <<~YAML)
          Layout/MultilineOperationIndentation:
            EnforcedStyle: aligned
            IndentationWidth: 1
        YAML
        expect(cli.run(['example.rb'])).to eq(2)
        expect($stderr.string.strip).to eq(
          'Error: The `Layout/MultilineOperationIndentation` cop only accepts' \
          ' an `IndentationWidth` configuration parameter when ' \
          '`EnforcedStyle` is `indented`.'
        )
      end
    end

    it 'allows the default configuration file as the -c argument' do
      create_file('example.rb', <<~RUBY)
        # frozen_string_literal: true

        x = 0
        puts x
      RUBY
      create_file('.rubocop.yml', [])

      expect(cli.run(%w[--format simple -c .rubocop.yml])).to eq(0)
      expect($stdout.string)
        .to eq(['', '1 file inspected, no offenses detected',
                ''].join("\n"))
    end

    context 'when --force-default-config option is specified' do
      shared_examples 'ignores config file' do
        it 'ignores config file' do
          create_file('example.rb', [
                        '# frozen_string_literal: true', '', 'x = 0 ', 'puts x'
                      ])
          create_file('.rubocop.yml', <<~YAML)
            Layout/TrailingWhitespace:
              Enabled: false
          YAML

          expect(cli.run(args)).to eq(1)
          expect($stdout.string)
            .to eq(<<~RESULT)
              == example.rb ==
              C:  3:  6: Layout/TrailingWhitespace: Trailing whitespace detected.

              1 file inspected, 1 offense detected
            RESULT
        end
      end

      context 'when no config file specified' do
        let(:args) { %w[--format simple --force-default-config] }

        include_examples 'ignores config file'
      end

      context 'when config file specified with -c' do
        let(:args) do
          %w[--format simple --force-default-config -c .rubocop.yml]
        end

        include_examples 'ignores config file'
      end
    end

    it 'displays cop names if DisplayCopNames is false' do
      source = ['# frozen_string_literal: true', '', 'x = 0 ', 'puts x']
      create_file('example1.rb', source)

      # DisplayCopNames: false inherited from config/default.yml
      create_file('.rubocop.yml', [])

      create_file('dir/example2.rb', source)
      create_file('dir/.rubocop.yml', <<~YAML)
        AllCops:
          DisplayCopNames: false
      YAML

      expect(cli.run(%w[--format simple])).to eq(1)
      expect($stdout.string).to eq(<<~RESULT)
        == dir/example2.rb ==
        C:  3:  6: Trailing whitespace detected.
        == example1.rb ==
        C:  3:  6: Layout/TrailingWhitespace: Trailing whitespace detected.

        2 files inspected, 2 offenses detected
      RESULT
    end

    it 'displays style guide URLs if DisplayStyleGuide is true' do
      source = ['# frozen_string_literal: true', '', 'x = 0 ', 'puts x']
      create_file('example1.rb', source)

      # DisplayCopNames: false inherited from config/default.yml
      create_file('.rubocop.yml', [])

      create_file('dir/example2.rb', source)
      create_file('dir/.rubocop.yml', <<~YAML)
        AllCops:
          DisplayStyleGuide: true
      YAML

      url = 'https://rubystyle.guide#no-trailing-whitespace'

      expect(cli.run(%w[--format simple])).to eq(1)
      expect($stdout.string).to eq(<<~RESULT)
        == dir/example2.rb ==
        C:  3:  6: Layout/TrailingWhitespace: Trailing whitespace detected. (#{url})
        == example1.rb ==
        C:  3:  6: Layout/TrailingWhitespace: Trailing whitespace detected.

        2 files inspected, 2 offenses detected
      RESULT
    end

    it 'uses the DefaultFormatter if another formatter is not specified' do
      source = ['# frozen_string_literal: true', '', 'x = 0 ', 'puts x']
      create_file('example1.rb', source)
      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          DefaultFormatter: offenses
      YAML

      expect(cli.run([])).to eq(1)
      expect($stdout.string)
        .to eq(<<~RESULT)

          1  Layout/TrailingWhitespace
          --
          1  Total

        RESULT
    end

    it 'finds included files' do
      create_file('file.rb', 'x=0') # Included by default
      create_file('example', 'x=0')
      create_file('regexp', 'x=0')
      create_file('vendor/bundle/ruby/2.4.0/gems/backports-3.6.8/.irbrc', 'x=0')
      create_file('.dot1/file.rb', 'x=0') # Hidden but explicitly included
      create_file('.dot2/file.rb', 'x=0') # Hidden, excluded by default
      create_file('.dot3/file.rake', 'x=0') # Hidden, not included by wildcard
      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Include:
            - "**/.irbrc"
            - example
            - "**/*.rb"
            - "**/*.rake"
            - !ruby/regexp /regexp$/
            - .dot1/**/*
          Exclude:
            - vendor/bundle/**/*
      YAML
      expect(cli.run(%w[--format files])).to eq(1)
      expect($stderr.string).to eq('')
      expect($stdout.string.split($RS).sort).to eq([abs('.dot1/file.rb'),
                                                    abs('example'),
                                                    abs('file.rb'),
                                                    abs('regexp')])
    end

    it 'ignores excluded files' do
      create_file('example.rb', ['x = 0', 'puts x'])
      create_file('regexp.rb', ['x = 0', 'puts x'])
      create_file('exclude_glob.rb', ['#!/usr/bin/env ruby', 'x = 0', 'puts x'])
      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - example.rb
            - !ruby/regexp /regexp.rb$/
            - "exclude_*"
      YAML
      expect(cli.run(%w[--format simple])).to eq(0)
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    it 'only reads configuration in explicitly included hidden directories' do
      create_file('.hidden/example.rb', 'x=0')
      # This file contains configuration for an unknown cop. This would cause a
      # warning to be printed on stderr if the file was read. But it's in a
      # hidden directory, so it's not read.
      create_file('.hidden/.rubocop.yml', <<~YAML)
        SymbolName:
          Enabled: false
      YAML

      create_file('.other/example.rb', <<~RUBY)
        # frozen_string_literal: true

        x=0
      RUBY
      # The .other directory is explicitly included, so the configuration file
      # is read, and modifies the behavior.
      create_file('.other/.rubocop.yml', <<~YAML)
        Layout/SpaceAroundOperators:
          Enabled: false
      YAML
      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Include:
            - .other/**/*
      YAML
      expect(cli.run(%w[--format simple])).to eq(1)
      expect($stderr.string).to eq('')
      expect($stdout.string)
        .to eq(<<~RESULT)
          == .other/example.rb ==
          W:  3:  1: Lint/UselessAssignment: Useless assignment to variable - x.

          1 file inspected, 1 offense detected
        RESULT
    end

    it 'does not consider Include parameters in subdirectories' do
      create_file('dir/example.ruby3', <<~RUBY)
        # frozen_string_literal: true

        x=0
      RUBY
      create_file('dir/.rubocop.yml', <<~YAML)
        AllCops:
          Include:
            - "*.ruby3"
      YAML
      expect(cli.run(%w[--format simple])).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string)
        .to eq(<<~RESULT)

          0 files inspected, no offenses detected
        RESULT
    end

    it 'matches included/excluded files correctly when . argument is given' do
      create_file('example.rb', <<~RUBY)
        # frozen_string_literal: true

        x = 0
      RUBY
      create_file('special.dsl', <<~RUBY)
        # frozen_string_literal: true

        setup { "stuff" }
      RUBY
      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Include:
            - "*.dsl"
          Exclude:
            - example.rb
      YAML
      expect(cli.run(%w[--format simple .])).to eq(1)
      expect($stdout.string).to eq(<<~RESULT)
        == special.dsl ==
        C:  3:  9: Style/StringLiterals: Prefer single-quoted strings when you don't need string interpolation or special symbols.

        1 file inspected, 1 offense detected
      RESULT
    end

    it 'does not read files in excluded list' do
      %w[rb.rb non-rb.ext without-ext].each do |filename|
        create_file("example/ignored/#{filename}", '#' * 90)
      end

      create_file('example/.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - ignored/**
      YAML
      expect(File).not_to receive(:open).with(%r{/ignored/})
      expect(cli.run(%w[--format simple example])).to eq(0)
      expect($stdout.string).to eq(<<~OUTPUT)

        0 files inspected, no offenses detected
      OUTPUT
    end

    it 'can be configured with option to disable a certain error' do
      create_file('example1.rb', [
                    '# frozen_string_literal: true', '', 'puts 0 '
                  ])
      create_file('rubocop.yml', <<~YAML)
        Style/Encoding:
          Enabled: false

        Layout/CaseIndentation:
          Enabled: false
      YAML
      expect(cli.run(['--format', 'simple',
                      '-c', 'rubocop.yml', 'example1.rb'])).to eq(1)
      expect($stdout.string)
        .to eq(<<~RESULT)
          == example1.rb ==
          C:  3:  7: Layout/TrailingWhitespace: Trailing whitespace detected.

          1 file inspected, 1 offense detected
        RESULT
    end

    context 'without using namespace' do
      it 'can be configured with option to disable a certain error' do
        create_file('example1.rb', [
                      '# frozen_string_literal: true', '', 'puts 0 '
                    ])
        create_file('rubocop.yml', <<~YAML)
          Encoding:
            Enabled: false

          CaseIndentation:
            Enabled: false
        YAML
        expect(cli.run(['--format', 'simple',
                        '-c', 'rubocop.yml', 'example1.rb'])).to eq(1)
        expect($stdout.string)
          .to eq(<<~RESULT)
            == example1.rb ==
            C:  3:  7: Layout/TrailingWhitespace: Trailing whitespace detected.

            1 file inspected, 1 offense detected
          RESULT
      end
    end

    it 'can disable parser-derived offenses with warning severity' do
      # `-' interpreted as argument prefix
      create_file('example.rb', [
                    '# frozen_string_literal: true', '', 'puts -1'
                  ])
      create_file('.rubocop.yml', <<~YAML)
        Style/Encoding:
          Enabled: false

        Lint/AmbiguousOperator:
          Enabled: false
      YAML
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(0)
    end

    it 'cannot disable Syntax offenses' do
      create_file('example.rb', 'class Test')
      create_file('.rubocop.yml', <<~YAML)
        Style/Encoding:
          Enabled: false

        Syntax:
          Enabled: false
      YAML
      expect(cli.run(['--format', 'emacs', 'example.rb'])).to eq(2)
      expect($stderr.string).to include(
        'Error: configuration for Syntax cop found'
      )
      expect($stderr.string).to include(
        'It\'s not possible to disable this cop.'
      )
    end

    it 'can be configured to merge a parameter that is a hash' do
      create_file('example1.rb', <<~RUBY)
        # frozen_string_literal: true

        puts %w(a b c)
        puts %q|hi|
      RUBY
      # We want to change the preferred delimiters for word arrays. The other
      # settings from default.yml are unchanged.
      create_file('rubocop.yml', <<~YAML)
        Style/PercentLiteralDelimiters:
          PreferredDelimiters:
            '%w': '[]'
            '%W': '[]'
      YAML
      cli.run(['--format', 'simple', '-c', 'rubocop.yml', 'example1.rb'])
      expect($stdout.string).to eq(<<~RESULT)
        == example1.rb ==
        C:  3:  6: Style/PercentLiteralDelimiters: %w-literals should be delimited by [ and ].
        C:  4:  6: Style/PercentLiteralDelimiters: %q-literals should be delimited by ( and ).
        C:  4:  6: Style/RedundantPercentQ: Use %q only for strings that contain both single quotes and double quotes.

        1 file inspected, 3 offenses detected
      RESULT
    end

    it 'can be configured to override a parameter that is a hash in a ' \
       'special case' do
      create_file('example1.rb', <<~RUBY)
        arr.select { |e| e > 0 }.collect { |e| e * 2 }
        a2.find_all { |e| e > 0 }
      RUBY
      # We prefer find_all over select. This setting overrides the default
      # select over find_all. Other preferred methods appearing in the default
      # config (e.g., map over collect) are kept.
      create_file('rubocop.yml', <<~YAML)
        Style/CollectionMethods:
          PreferredMethods:
            select: find_all
      YAML
      cli.run(['--format',
               'simple',
               '-c',
               'rubocop.yml',
               '--only',
               'CollectionMethods',
               'example1.rb'])
      expect($stdout.string)
        .to eq(<<~RESULT)
          == example1.rb ==
          C:  1:  5: Style/CollectionMethods: Prefer find_all over select.
          C:  1: 26: Style/CollectionMethods: Prefer map over collect.

          1 file inspected, 2 offenses detected
        RESULT
    end

    it 'works when a cop that others depend on is disabled' do
      create_file('example1.rb', <<~RUBY)
        # frozen_string_literal: true

        if a
          b
        end
      RUBY
      create_file('rubocop.yml', <<~YAML)
        Style/Encoding:
          Enabled: false

        Layout/LineLength:
          Enabled: false
      YAML
      result = cli.run(['--format', 'simple',
                        '-c', 'rubocop.yml', 'example1.rb'])
      expect($stdout.string).to eq(<<~RESULT)
        == example1.rb ==
        C:  3:  1: Style/IfUnlessModifier: Favor modifier if usage when having a single-line body. Another good alternative is the usage of control flow &&/||.

        1 file inspected, 1 offense detected
      RESULT
      expect(result).to eq(1)
    end

    it 'can be configured with project config to disable a certain error' do
      create_file('example_src/example1.rb', [
                    '# frozen_string_literal: true', '', 'puts 0 '
                  ])
      create_file('example_src/.rubocop.yml', <<~YAML)
        Style/Encoding:
          Enabled: false

        Layout/CaseIndentation:
          Enabled: false
      YAML
      expect(cli.run(['--format', 'simple',
                      'example_src/example1.rb'])).to eq(1)
      expect($stdout.string)
        .to eq(<<~RESULT)
          == example_src/example1.rb ==
          C:  3:  7: Layout/TrailingWhitespace: Trailing whitespace detected.

          1 file inspected, 1 offense detected
        RESULT
    end

    it 'can use an alternative max line length from a config file' do
      create_file('example_src/example1.rb', <<~RUBY)
        # frozen_string_literal: true

        #{'#' * 90}
      RUBY
      create_file('example_src/.rubocop.yml', <<~YAML)
        Layout/LineLength:
          Enabled: true
          Max: 100
      YAML
      expect(cli.run(['--format', 'simple',
                      'example_src/example1.rb'])).to eq(0)
      expect($stdout.string)
        .to eq(['', '1 file inspected, no offenses detected', ''].join("\n"))
    end

    it 'can have different config files in different directories' do
      %w[src lib].each do |dir|
        create_file("example/#{dir}/example1.rb", <<~RUBY)
          # frozen_string_literal: true

          #{'#' * 130}
        RUBY
      end
      create_file('example/src/.rubocop.yml', <<~YAML)
        Layout/LineLength:
          Enabled: true
          Max: 140
      YAML
      expect(cli.run(%w[--format simple example])).to eq(1)
      expect($stdout.string).to eq(<<~RESULT)
        == example/lib/example1.rb ==
        C:  3:121: Layout/LineLength: Line is too long. [130/120]

        2 files inspected, 1 offense detected
      RESULT
    end

    it 'prefers a config file in ancestor directory to another in home' do
      create_file('example_src/example1.rb', <<~RUBY)
        # frozen_string_literal: true

        #{'#' * 90}
      RUBY
      create_file('example_src/.rubocop.yml', <<~YAML)
        Layout/LineLength:
          Enabled: true
          Max: 100
      YAML
      create_file("#{Dir.home}/.rubocop.yml", <<~YAML)
        Layout/LineLength:
          Enabled: true
          Max: 80
      YAML
      expect(cli.run(['--format', 'simple',
                      'example_src/example1.rb'])).to eq(0)
      expect($stdout.string)
        .to eq(['', '1 file inspected, no offenses detected', ''].join("\n"))
    end

    it 'can exclude directories relative to .rubocop.yml' do
      %w[src etc/test etc/spec tmp/test tmp/spec].each do |dir|
        create_file("example/#{dir}/example1.rb", <<~RUBY)
          # frozen_string_literal: true

          #{'#' * 130}
        RUBY
      end

      # Hidden subdirectories should also be excluded.
      create_file('example/etc/.dot/example1.rb', <<~RUBY)
        # frozen_string_literal: true

        #{'#' * 130}
      RUBY

      create_file('example/.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - src/**
            - etc/**/*
            - tmp/spec/**
      YAML

      expect(cli.run(%w[--format simple example])).to eq(1)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<~RESULT)
        == example/tmp/test/example1.rb ==
        C:  3:121: Layout/LineLength: Line is too long. [130/120]

        1 file inspected, 1 offense detected
      RESULT
    end

    it 'can exclude a typical vendor directory' do
      create_file(
        'vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/.rubocop.yml',
        <<~YAML
          AllCops:
            Exclude:
              - lib/parser/lexer.rb
        YAML
      )

      create_file('vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/lib/ex.rb',
                  '#' * 90)

      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - vendor/**/*
      YAML

      cli.run(%w[--format simple])
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    it 'excludes the vendor directory by default' do
      create_file('vendor/ex.rb', '#' * 90)

      cli.run(%w[--format simple])
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    # Being immune to bad configuration files in excluded directories has
    # become important due to a bug in rubygems
    # (https://github.com/rubygems/rubygems/issues/680) that makes
    # installations of, for example, rubocop lack their .rubocop.yml in the
    # root directory.
    it 'can exclude a vendor directory with an erroneous config file' do
      create_file('vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/.rubocop.yml',
                  ['inherit_from: non_existent.yml'])

      create_file('vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/lib/ex.rb',
                  '#' * 130)

      create_file('.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - vendor/**/*
      YAML

      cli.run(%w[--format simple])
      expect($stderr.string).to eq('')
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    # Relative exclude paths in .rubocop.yml files are relative to that file,
    # but in configuration files with other names they will be relative to
    # whatever file inherits from them.
    it 'can exclude a vendor directory indirectly' do
      create_file(
        'vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/.rubocop.yml',
        <<~YAML
          AllCops:
            Exclude:
              - lib/parser/lexer.rb
        YAML
      )

      create_file('vendor/bundle/ruby/1.9.1/gems/parser-2.0.0/lib/ex.rb',
                  '#' * 90)

      create_file('.rubocop.yml',
                  ['inherit_from: config/default.yml'])

      create_file('config/default.yml', <<~YAML)
        AllCops:
          Exclude:
            - vendor/**/*
      YAML

      cli.run(%w[--format simple])
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    it 'prints an error for an unrecognized cop name in .rubocop.yml' do
      create_file('example/example1.rb', '#' * 90)

      create_file('example/.rubocop.yml', <<~YAML)
        Style/LyneLenth:
          Enabled: true
          Max: 100
      YAML

      expect(cli.run(%w[--format simple example])).to eq(2)
      expect($stderr.string)
        .to eq(['Error: unrecognized cop Style/LyneLenth found in ' \
                'example/.rubocop.yml',
                ''].join("\n"))
    end

    it 'prints a warning for an unrecognized configuration parameter' do
      create_file('example/example1.rb', '#' * 90)

      create_file('example/.rubocop.yml', <<~YAML)
        Layout/LineLength:
          Enabled: true
          Min: 10
      YAML

      expect(cli.run(%w[--format simple example])).to eq(1)

      expect($stderr.string).to eq(<<-RESULT.strip_margin('|'))
        |Warning: Layout/LineLength does not support Min parameter.
        |
        |Supported parameters are:
        |
        |  - Enabled
        |  - AutoCorrect
        |  - Max
        |  - AllowHeredoc
        |  - AllowURI
        |  - URISchemes
        |  - IgnoreCopDirectives
        |  - IgnoredPatterns
      RESULT
    end

    it 'prints an error message for an unrecognized EnforcedStyle' do
      create_file('example/example1.rb', 'puts "hello"')
      create_file('example/.rubocop.yml', <<~YAML)
        Layout/AccessModifierIndentation:
          EnforcedStyle: ident
      YAML

      expect(cli.run(%w[--format simple example])).to eq(2)
      expect($stderr.string)
        .to eq(["Error: invalid EnforcedStyle 'ident' for " \
                'Layout/AccessModifierIndentation found in ' \
                'example/.rubocop.yml',
                'Valid choices are: outdent, indent',
                ''].join("\n"))
    end

    it 'works when a configuration file passed by -c specifies Exclude ' \
       'with regexp' do
      create_file('example/example1.rb', '#' * 90)

      create_file('rubocop.yml', <<~'YAML')
        AllCops:
          Exclude:
            - !ruby/regexp /example1\.rb$/
      YAML

      cli.run(%w[--format simple -c rubocop.yml])
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    it 'works when a configuration file passed by -c specifies Exclude ' \
       'with strings' do
      create_file('example/example1.rb', '#' * 90)

      create_file('rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - example/**
      YAML

      cli.run(%w[--format simple -c rubocop.yml])
      expect($stdout.string)
        .to eq(['', '0 files inspected, no offenses detected',
                ''].join("\n"))
    end

    shared_examples 'specified Severity' do |key|
      it 'works when a configuration file specifies Severity for ' \
         "Metrics/ParameterLists and #{key}" do
        create_file('example/example1.rb', <<~RUBY)
          # frozen_string_literal: true

          def method(foo, bar, qux, fred, arg5, f) end #{'#' * 85}
        RUBY

        create_file('rubocop.yml', <<~YAML)
          #{key}:
            Severity: error
          Metrics/ParameterLists:
            Severity: convention
        YAML

        cli.run(%w[--format simple -c rubocop.yml])
        expect($stdout.string).to eq(<<~RESULT)
          == example/example1.rb ==
          C:  3: 11: Metrics/ParameterLists: Avoid parameter lists longer than 5 parameters. [6/5]
          C:  3: 39: Naming/MethodParameterName: Method parameter must be at least 3 characters long.
          C:  3: 46: Style/CommentedKeyword: Do not place comments on the same line as the def keyword.
          E:  3:121: Layout/LineLength: Line is too long. [130/120]

          1 file inspected, 4 offenses detected
        RESULT
        expect($stderr.string).to eq('')
      end
    end

    include_examples 'specified Severity', 'Layout/LineLength'
    include_examples 'specified Severity', 'Layout'

    it 'fails when a configuration file specifies an invalid Severity' do
      create_file('example/example1.rb', '#' * 130)

      create_file('rubocop.yml', <<~YAML)
        Layout/LineLength:
          Severity: superbad
      YAML

      cli.run(%w[--format simple -c rubocop.yml])
      expect($stderr.string)
        .to eq(["Warning: Invalid severity 'superbad'. " \
                'Valid severities are refactor, convention, ' \
                'warning, error, fatal.',
                ''].join("\n"))
    end

    it 'fails when a configuration file has invalid YAML syntax' do
      create_file('example/.rubocop.yml', <<~YAML)
        AllCops:
          Exclude:
            - **/*_old.rb
      YAML

      cli.run(['example'])
      # MRI and JRuby return slightly different error messages.
      expect($stderr.string)
        .to match(%r{^\(\S+example/\.rubocop\.yml\):\ (did\ not\ find\ )?
                  expected\ alphabetic\ or \ numeric\ character}x)
    end

    context 'when a file inherits from a higher level' do
      before do
        create_file('.rubocop.yml', <<~YAML)
          Layout/LineLength:
            Exclude:
              - dir/example.rb
        YAML
        create_file('dir/.rubocop.yml', 'inherit_from: ../.rubocop.yml')
        create_file('dir/example.rb', <<~RUBY)
          # frozen_string_literal: true

          #{'#' * 90}
        RUBY
      end

      it 'inherits relative excludes correctly' do
        expect(cli.run([])).to eq(0)
      end
    end

    context 'when configuration is taken from $HOME/.rubocop.yml' do
      before do
        create_file("#{Dir.home}/.rubocop.yml", <<~YAML)
          Layout/LineLength:
            Exclude:
              - dir/example.rb
        YAML
        create_file('dir/example.rb', <<~RUBY)
          # frozen_string_literal: true

          #{'#' * 90}
        RUBY
      end

      it 'handles relative excludes correctly when run from project root' do
        expect(cli.run([])).to eq(0)
      end
    end

    it 'shows an error if the input file cannot be found' do
      begin
        cli.run(%w[/tmp/not_a_file])
      rescue SystemExit => e
        expect(e.status).to eq(1)
        expect(e.message)
          .to eq 'rubocop: No such file or directory -- /tmp/not_a_file'
      end
    end
  end

  describe 'configuration of target Ruby versions' do
    context 'when configured with an unknown version' do
      it 'fails with an error message' do
        create_file('.rubocop.yml', <<~YAML)
          AllCops:
            TargetRubyVersion: 2.8
        YAML
        expect(cli.run([])).to eq(2)
        expect($stderr.string.strip).to start_with(
          'Error: RuboCop found unknown Ruby version 2.8 in `TargetRubyVersion`'
        )
        expect($stderr.string.strip).to match(
          /Supported versions: 2.4, 2.5, 2.6, 2.7/
        )
      end
    end

    context 'when configured with an unsupported ruby' do
      it 'fails with an error message' do
        create_file('.rubocop.yml', <<~YAML)
          AllCops:
            TargetRubyVersion: 2.0
        YAML

        expect(cli.run([])).to eq(2)
        expect($stderr.string.strip).to start_with(
          'Error: RuboCop found unsupported Ruby version 2.0 in '\
          '`TargetRubyVersion`'
        )

        expect($stderr.string.strip).to match(
          /2\.0-compatible analysis was dropped after version 0\.50/
        )

        expect($stderr.string.strip).to match(
          /Supported versions: 2.4/
        )
      end
    end
  end

  context 'configuration of `require`' do
    context 'unknown library is specified' do
      it 'exits with 2' do
        create_file('.rubocop.yml', <<~YAML)
          require: unknownlibrary
        YAML

        regexp =
          if RUBY_ENGINE == 'jruby'
            /no such file to load -- unknownlibrary/
          else
            /cannot load such file -- unknownlibrary/
          end
        expect(cli.run([])).to eq(2)
        expect($stderr.string).to match(regexp)
      end
    end
  end

  describe 'obsolete cops' do
    context 'when configuration for TrailingComma is given' do
      it 'fails with an error message' do
        create_file('example1.rb', "puts 'hello'")
        create_file('.rubocop.yml', <<~YAML)
          Style/TrailingComma:
            Enabled: true
        YAML
        expect(cli.run(['example1.rb'])).to eq(2)
        expect($stderr.string.strip).to eq(
          ['Error: The `Style/TrailingComma` cop has been removed. Please ' \
           'use `Style/TrailingCommaInArguments`, ' \
           '`Style/TrailingCommaInArrayLiteral`, and/or ' \
           '`Style/TrailingCommaInHashLiteral` instead.',
           '(obsolete configuration found in .rubocop.yml, ' \
           'please update it)'].join("\n")
        )
      end
    end
  end

  describe 'unknown cop' do
    context 'in configuration file is given' do
      it 'prints the error and exists with code 2' do
        create_file('example1.rb', "puts 'no offenses here'")
        create_file('.rubocop.yml', <<~YAML)
          Syntax/Whatever:
            Enabled: true
        YAML
        expect(cli.run(['example1.rb'])).to eq(2)
        expect($stderr.string.strip).to eq(
          'Error: unrecognized cop Syntax/Whatever found in .rubocop.yml'
        )
      end
    end
  end
end
