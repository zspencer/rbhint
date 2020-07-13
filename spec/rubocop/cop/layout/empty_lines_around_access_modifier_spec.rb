# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::EmptyLinesAroundAccessModifier, :config do
  context 'EnforcedStyle is `around`' do
    let(:cop_config) { { 'EnforcedStyle' => 'around' } }

    %w[private protected public module_function].each do |access_modifier|
      it "requires blank line before #{access_modifier}" do
        inspect_source(<<~RUBY)
          class Test
            something
            #{access_modifier}

            def test; end
          end
        RUBY
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Keep a blank line before and after `#{access_modifier}`."])
      end

      it "requires blank line after #{access_modifier}" do
        inspect_source(<<~RUBY)
          class Test
            something

            #{access_modifier}
            def test; end
          end
        RUBY
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Keep a blank line before and after `#{access_modifier}`."])
      end

      it "ignores comment line before #{access_modifier}" do
        expect_no_offenses(<<~RUBY)
          class Test
            something

            # This comment is fine
            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it "ignores #{access_modifier} inside a method call" do
        expect_no_offenses(<<~RUBY)
          class Test
            def #{access_modifier}?
              #{access_modifier}
            end
          end
        RUBY
      end

      it "ignores an accessor with the same name as #{access_modifier} " \
         'above a method definition' do
        expect_no_offenses(<<~RUBY)
          class Test
            attr_reader #{access_modifier}
            def foo
            end
          end
        RUBY
      end

      it "ignores #{access_modifier} deep inside a method call" do
        expect_no_offenses(<<~RUBY)
          class Test
            def #{access_modifier}?
              if true
                #{access_modifier}
              end
            end
          end
        RUBY
      end

      it "ignores #{access_modifier} with a right-hand-side condition" do
        expect_no_offenses(<<~RUBY)
          class Test
            def #{access_modifier}?
              #{access_modifier} if true
            end
          end
        RUBY
      end

      it "autocorrects blank line before #{access_modifier}" do
        corrected = autocorrect_source(<<~RUBY)
          class Test
            something
            #{access_modifier}

            def test; end
          end
        RUBY
        expect(corrected).to eq(<<~RUBY)
          class Test
            something

            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it 'autocorrects blank line after #{access_modifier}' do
        corrected = autocorrect_source(<<~RUBY)
          class Test
            something

            #{access_modifier}
            def test; end
          end
        RUBY
        expect(corrected).to eq(<<~RUBY)
          class Test
            something

            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it 'autocorrects blank line after #{access_modifier} with comment' do
        corrected = autocorrect_source(<<~RUBY)
          class Test
            something

            #{access_modifier} # let's modify the rest
            def test; end
          end
        RUBY
        expect(corrected).to eq(<<~RUBY)
          class Test
            something

            #{access_modifier} # let's modify the rest

            def test; end
          end
        RUBY
      end

      it 'accepts missing blank line when at the beginning of class' do
        expect_no_offenses(<<~RUBY)
          class Test
            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it 'accepts missing blank line when at the beginning of module' do
        expect_no_offenses(<<~RUBY)
          module Test
            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it 'accepts missing blank line when at the beginning of sclass' do
        expect_no_offenses(<<~RUBY)
          class << self
            #{access_modifier}

            def test; end
          end
        RUBY
      end

      it 'accepts missing blank line when specifying a superclass ' \
         'that breaks the line' do
        expect_no_offenses(<<~RUBY)
          class Foo <
                Bar
            #{access_modifier}

            def do_something
            end
          end
        RUBY
      end

      it 'accepts missing blank line when specifying `self` ' \
         'that breaks the line' do
        expect_no_offenses(<<~RUBY)
          class <<
                self
            #{access_modifier}

            def do_something
            end
          end
        RUBY
      end

      it 'accepts missing blank line when at the beginning of file' \
         'when specifying a superclass that breaks the line' do
        expect_no_offenses(<<~RUBY)
          #{access_modifier}

          def do_something
          end
        RUBY
      end

      it "requires blank line after, but not before, #{access_modifier} " \
         'when at the beginning of class/module' do
        inspect_source(<<~RUBY)
          class Test
            #{access_modifier}
            def test
            end
          end
        RUBY
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Keep a blank line after `#{access_modifier}`."])
      end

      context 'at the beginning of block' do
        context 'for blocks defined with do' do
          it 'accepts missing blank line' do
            expect_no_offenses(<<~RUBY)
              included do
                #{access_modifier}

                def test; end
              end
            RUBY
          end

          it 'accepts missing blank line with arguments' do
            expect_no_offenses(<<~RUBY)
              included do |foo|
                #{access_modifier}

                def test; end
              end
            RUBY
          end

          it "requires blank line after, but not before, #{access_modifier}" do
            inspect_source(<<~RUBY)
              included do
                #{access_modifier}
                def test
                end
              end
            RUBY
            expect(cop.offenses.size).to eq(1)
            expect(cop.messages)
              .to eq(["Keep a blank line after `#{access_modifier}`."])
          end
        end

        context 'for blocks defined with {}' do
          it 'accepts missing blank line' do
            expect_no_offenses(<<~RUBY)
              included {
                #{access_modifier}

                def test; end
              }
            RUBY
          end

          it 'accepts missing blank line with arguments' do
            expect_no_offenses(<<~RUBY)
              included { |foo|
                #{access_modifier}

                def test; end
              }
            RUBY
          end
        end
      end

      it 'accepts missing blank line when at the end of block' do
        expect_no_offenses(<<~RUBY)
          class Test
            def test; end

            #{access_modifier}
          end
        RUBY
      end

      it 'accepts missing blank line when at the end of specifying ' \
         'a superclass' do
        expect_no_offenses(<<~RUBY)
          class Test < Base
            def test; end

            #{access_modifier}
          end
        RUBY
      end

      it 'accepts missing blank line when at the end of specifying ' \
         '`self`' do
        expect_no_offenses(<<~RUBY)
          class << self
            def test; end

            #{access_modifier}
          end
        RUBY
      end

      it 'requires blank line when next line started with end' do
        inspect_source(<<~RUBY)
          class Test
            #{access_modifier}
            end_this!
          end
        RUBY

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Keep a blank line after `#{access_modifier}`."])
      end

      it 'recognizes blank lines with DOS style line endings' do
        expect_no_offenses(<<~RUBY)
          class Test\r
          \r
            #{access_modifier}\r
          \r
            def test; end\r
          end\r
        RUBY
      end
    end
  end

  context 'EnforcedStyle is `only_before`' do
    let(:cop_config) { { 'EnforcedStyle' => 'only_before' } }

    %w[private protected].each do |access_modifier|
      it "accepts missing blank line after #{access_modifier}" do
        expect_no_offenses(<<~RUBY)
          class Test
            something

            #{access_modifier}
            def test; end
          end
        RUBY
      end

      it "registers an offense for blank line after #{access_modifier}" do
        inspect_source(<<~RUBY)
          class Test
            something

            #{access_modifier}

            def test; end
          end
        RUBY

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Remove a blank line after `#{access_modifier}`."])
      end

      it "autocorrects remove blank line after #{access_modifier}" do
        corrected = autocorrect_source(<<~RUBY)
          class Test
            something

            #{access_modifier}

            def test; end
          end
        RUBY

        expect(corrected).to eq(<<~RUBY)
          class Test
            something

            #{access_modifier}
            def test; end
          end
        RUBY
      end

      it "does not register an offense when `end` immediately after #{access_modifier}" do
        expect_no_offenses(<<~RUBY)
          class Test
            #{access_modifier}
          end
        RUBY
      end
    end

    %w[public module_function].each do |access_modifier|
      it "accepts blank line after #{access_modifier}" do
        expect_no_offenses(<<~RUBY)
          module Kernel
            #{access_modifier}

            def do_something
            end
          end
        RUBY
      end
    end

    %w[private protected public module_function].each do |access_modifier|
      it "registers an offense for missing blank line before #{access_modifier}" do
        inspect_source(<<~RUBY)
          class Test
            something
            #{access_modifier}
            def test; end
          end
        RUBY
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq(["Keep a blank line before `#{access_modifier}`."])
      end

      it 'autocorrects blank line before #{access_modifier}' do
        corrected = autocorrect_source(<<~RUBY)
          class Test
            something
            #{access_modifier}
            def test; end
          end
        RUBY

        expect(corrected).to eq(<<~RUBY)
          class Test
            something

            #{access_modifier}
            def test; end
          end
        RUBY
      end
    end
  end
end
