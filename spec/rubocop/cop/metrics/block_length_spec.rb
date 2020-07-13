# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Metrics::BlockLength, :config do
  let(:cop_config) { { 'Max' => 2, 'CountComments' => false } }

  shared_examples 'ignoring an offense on an excluded method' do |excluded|
    before { cop_config['ExcludedMethods'] = [excluded] }

    it 'still rejects other methods with long blocks' do
      expect_offense(<<~RUBY)
        something do
        ^^^^^^^^^^^^ Block has too many lines. [3/2]
          a = 1
          a = 2
          a = 3
        end
      RUBY
    end

    it 'accepts the foo method with a long block' do
      expect_no_offenses(<<~RUBY)
        #{excluded} do
          a = 1
          a = 2
          a = 3
        end
      RUBY
    end
  end

  it 'rejects a block with more than 5 lines' do
    expect_offense(<<~RUBY)
      something do
      ^^^^^^^^^^^^ Block has too many lines. [3/2]
        a = 1
        a = 2
        a = 3
      end
    RUBY
  end

  it 'reports the correct beginning and end lines' do
    inspect_source(<<~RUBY)
      something do
        a = 1
        a = 2
        a = 3
      end
    RUBY
    offense = cop.offenses.first
    expect(offense.location.first_line).to eq(1)
    expect(offense.location.last_line).to eq(5)
  end

  it 'accepts a block with less than 3 lines' do
    expect_no_offenses(<<~RUBY)
      something do
        a = 1
        a = 2
      end
    RUBY
  end

  it 'does not count blank lines' do
    expect_no_offenses(<<~RUBY)
      something do
        a = 1


        a = 4
      end
    RUBY
  end

  it 'accepts a block with multiline receiver and less than 3 lines of body' do
    expect_no_offenses(<<~RUBY)
      [
        :a,
        :b,
        :c,
      ].each do
        a = 1
        a = 2
      end
    RUBY
  end

  it 'accepts empty blocks' do
    expect_no_offenses(<<~RUBY)
      something do
      end
    RUBY
  end

  it 'rejects brace blocks too' do
    expect_offense(<<~RUBY)
      something {
      ^^^^^^^^^^^ Block has too many lines. [3/2]
        a = 1
        a = 2
        a = 3
      }
    RUBY
  end

  it 'properly counts nested blocks' do
    expect_offense(<<~RUBY)
      something do
      ^^^^^^^^^^^^ Block has too many lines. [6/2]
        something do
        ^^^^^^^^^^^^ Block has too many lines. [4/2]
          a = 2
          a = 3
          a = 4
          a = 5
        end
      end
    RUBY
  end

  it 'does not count commented lines by default' do
    expect_no_offenses(<<~RUBY)
      something do
        a = 1
        #a = 2
        #a = 3
        a = 4
      end
    RUBY
  end

  context 'when defining a class' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        Class.new do
          a = 1
          a = 2
          a = 3
          a = 4
          a = 5
          a = 6
        end
      RUBY
    end
  end

  context 'when defining a module' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        Module.new do
          a = 1
          a = 2
          a = 3
          a = 4
          a = 5
          a = 6
        end
      RUBY
    end
  end

  context 'when CountComments is enabled' do
    before { cop_config['CountComments'] = true }

    it 'also counts commented lines' do
      expect_offense(<<~RUBY)
        something do
        ^^^^^^^^^^^^ Block has too many lines. [3/2]
          a = 1
          #a = 2
          a = 3
        end
      RUBY
    end
  end

  context 'when `CountAsOne` is not empty' do
    before { cop_config['CountAsOne'] = ['array'] }

    it 'folds array into one line' do
      expect_no_offenses(<<~RUBY)
        something do
          a = 1
          a = [
            2,
            3
          ]
        end
      RUBY
    end
  end

  context 'when ExcludedMethods is enabled' do
    it_behaves_like('ignoring an offense on an excluded method', 'foo')

    it_behaves_like('ignoring an offense on an excluded method',
                    'Gem::Specification.new')

    context 'when receiver contains whitespaces' do
      before { cop_config['ExcludedMethods'] = ['Foo::Bar.baz'] }

      it 'ignores whitespaces' do
        expect_no_offenses(<<~RUBY)
          Foo::
            Bar.baz do
            a = 1
            a = 2
            a = 3
          end
        RUBY
      end
    end

    context 'when a method is ignored, but receiver is a module' do
      before { cop_config['ExcludedMethods'] = ['baz'] }

      it 'does not report an offense' do
        expect_no_offenses(<<~RUBY)
          Foo::Bar.baz do
            a = 1
            a = 2
            a = 3
          end
        RUBY
      end
    end
  end
end
