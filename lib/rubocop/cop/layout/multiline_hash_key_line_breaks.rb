# frozen_string_literal: true

module RuboCop
  module Cop
    module Layout
      # This hint ensures that each key in a multi-line hash
      # starts on a separate line.
      #
      # @example
      #
      #   # bad
      #   {
      #     a: 1, b: 2,
      #     c: 3
      #   }
      #
      #   # good
      #   {
      #     a: 1,
      #     b: 2,
      #     c: 3
      #   }
      class MultilineHashKeyLineBreaks < Cop
        include MultilineElementLineBreaks

        MSG = 'Each key in a multi-line hash must start on a ' \
          'separate line.'

        def on_hash(node)
          # This cop only deals with hashes wrapped by a set of curly
          # braces like {foo: 1}. That is, not a kwargs hashes.
          # Style/MultilineMethodArgumentLineBreaks handles those.
          return unless starts_with_curly_brace?(node)

          check_line_breaks(node, node.children) if node.loc.begin
        end

        def autocorrect(node)
          EmptyLineCorrector.insert_before(node)
        end

        private

        def starts_with_curly_brace?(node)
          node.loc.begin
        end
      end
    end
  end
end
