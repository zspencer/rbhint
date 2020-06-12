# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Naming::VariableName, :config do
  shared_examples 'always accepted' do
    it 'accepts screaming snake case globals' do
      expect_no_offenses('$MY_GLOBAL = 0')
    end

    it 'accepts screaming snake case constants' do
      expect_no_offenses('MY_CONSTANT = 0')
    end

    it 'accepts assigning to camel case constant' do
      expect_no_offenses('Paren = Struct.new :left, :right, :kind')
    end

    it 'accepts assignment with indexing of self' do
      expect_no_offenses('self[:a] = b')
    end

    it 'accepts local variables marked as unused' do
      expect_no_offenses('_ = 1')
    end

    it 'accepts one symbol size local variables' do
      expect_no_offenses('i = 1')
    end
  end

  context 'when configured for snake_case' do
    let(:cop_config) { { 'EnforcedStyle' => 'snake_case' } }

    it 'registers an offense for camel case in local variable name' do
      expect_offense(<<~RUBY)
        myLocal = 1
        ^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for correct + opposite' do
      expect_offense(<<~RUBY)
        my_local = 1
        myLocal = 1
        ^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for camel case in instance variable name' do
      expect_offense(<<~RUBY)
        @myAttribute = 3
        ^^^^^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for camel case in class variable name' do
      expect_offense(<<~RUBY)
        @@myAttr = 2
        ^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for camel case local variables marked as unused' do
      expect_offense(<<~RUBY)
        _myLocal = 1
        ^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for method arguments' do
      expect_offense(<<~RUBY)
        def method(funnyArg); end
                   ^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for default method arguments' do
      expect_offense(<<~RUBY)
        def foo(optArg = 1); end
                ^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for rest arguments' do
      expect_offense(<<~RUBY)
        def foo(*restArg); end
                 ^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for keyword arguments' do
      expect_offense(<<~RUBY)
        def foo(kwArg: 1); end
                ^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for keyword rest arguments' do
      expect_offense(<<~RUBY)
        def foo(**kwRest); end
                  ^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for block arguments' do
      expect_offense(<<~RUBY)
        def foo(&blockArg); end
                 ^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    it 'registers an offense for camel case when invoking method args' do
      expect_offense(<<~RUBY)
        firstArg = 'foo'
        ^^^^^^^^ Use snake_case for variable names.
        secondArg = 'foo'
        ^^^^^^^^^ Use snake_case for variable names.

        do_something(firstArg, secondArg)
                     ^^^^^^^^ Use snake_case for variable names.
                               ^^^^^^^^^ Use snake_case for variable names.
      RUBY
    end

    include_examples 'always accepted'
  end

  context 'when configured for camelCase' do
    let(:cop_config) { { 'EnforcedStyle' => 'camelCase' } }

    it 'registers an offense for snake case in local variable name' do
      expect_offense(<<~RUBY)
        my_local = 1
        ^^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for opposite + correct' do
      expect_offense(<<~RUBY)
        my_local = 1
        ^^^^^^^^ Use camelCase for variable names.
        myLocal = 1
      RUBY
    end

    it 'accepts camel case in local variable name' do
      expect_no_offenses('myLocal = 1')
    end

    it 'accepts camel case in instance variable name' do
      expect_no_offenses('@myAttribute = 3')
    end

    it 'accepts camel case in class variable name' do
      expect_no_offenses('@@myAttr = 2')
    end

    it 'registers an offense for snake case in method parameter' do
      expect_offense(<<~RUBY)
        def method(funny_arg); end
                   ^^^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'accepts camel case local variables marked as unused' do
      expect_no_offenses('_myLocal = 1')
    end

    it 'registers an offense for default method arguments' do
      expect_offense(<<~RUBY)
        def foo(opt_arg = 1); end
                ^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for rest arguments' do
      expect_offense(<<~RUBY)
        def foo(*rest_arg); end
                 ^^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for keyword arguments' do
      expect_offense(<<~RUBY)
        def foo(kw_arg: 1); end
                ^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for keyword rest arguments' do
      expect_offense(<<~RUBY)
        def foo(**kw_rest); end
                  ^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for block arguments' do
      expect_offense(<<~RUBY)
        def foo(&block_arg); end
                 ^^^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    it 'registers an offense for camel case when invoking method args' do
      expect_offense(<<~RUBY)
        first_arg = 'foo'
        ^^^^^^^^^ Use camelCase for variable names.
        second_arg = 'foo'
        ^^^^^^^^^^ Use camelCase for variable names.

        do_something(first_arg, second_arg)
                     ^^^^^^^^^ Use camelCase for variable names.
                                ^^^^^^^^^^ Use camelCase for variable names.
      RUBY
    end

    include_examples 'always accepted'
  end
end
