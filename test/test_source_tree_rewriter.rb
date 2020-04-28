# frozen_string_literal: true

require 'helper'

class TestSourceTreeRewriter < Minitest::Test
  def setup
    @buf = Parser::Source::Buffer.new('(rewriter)')
    @buf.source = 'puts(:hello, :world)'

    @hello = range(5, 6)
    @ll = range(7, 2)
    @comma_space = range(11,2)
    @world = range(13,6)
    @whole = range(0, @buf.source.length)
  end

  def range(from, len)
    Parser::Source::Range.new(@buf, from, from + len)
  end

  # Returns either:
  #  - yield rewriter
  #  - [diagnostic, ...] (Diagnostics)
  #  - Parser::ClobberingError
  #
  def build(actions, **policy)
    diagnostics = []
    diags = -> { diagnostics.flatten.map(&:strip).join("\n") }
    rewriter = Parser::Source::TreeRewriter.new(@buf, **policy)
    rewriter.diagnostics.consumer = -> diag { diagnostics << diag.render }
    actions.each do |action, range, *args|
      rewriter.public_send(action, range, *args)
    end
    if diagnostics.empty?
      yield rewriter
    else
      diags.call
    end
  rescue ::Parser::ClobberingError => e
    [::Parser::ClobberingError, diags.call]
  end

  # Returns either:
  #  - String (Normal operation)
  #  - [diagnostic, ...] (Diagnostics)
  #  - Parser::ClobberingError
  #
  def apply(actions, **policy)
    build(actions, **policy) { |rewriter| rewriter.process }
  end

  # Expects ordered actions to be grouped together
  def check_actions(expected, grouped_actions, **policy)
    grouped_actions.permutation do |sequence|
      # [action, [action, action]]  => [action, action, action]
      # except we can't use flatten because "action" are arrays themselves
      actions = sequence.flat_map { |group| group.first.is_a?(Array) ? group : [group] }
      assert_equal(expected, apply(actions, **policy))
    end
  end

  def assert_actions_result(expected, *actions, **rest)
    if expected == :raise
      diagnostic = rest.values.first
      check_actions([::Parser::ClobberingError, diagnostic], actions)
    elsif rest.empty?
      check_actions(expected, actions)
    else
      policy, diagnostic = rest.first
      check_actions(expected, actions, policy => :accept)
      check_actions(diagnostic, actions, policy => :warn)
      diagnostic.gsub!(/warning: /, 'error: ')
      check_actions([::Parser::ClobberingError, diagnostic], actions, policy => :raise)
    end
  end

  ### Simple cases

  def test_remove
    assert_actions_result 'puts(, :world)', [:remove, @hello]
  end

  def test_insert_before
    assert_actions_result 'puts(:hello, 42, :world)', [:insert_before, @world, '42, ']
  end

  def test_insert_after
    assert_actions_result 'puts(:hello, 42, :world)', [:insert_after, @hello, ', 42']
  end

  def test_wrap
    assert_actions_result 'puts([:hello], :world)', [:wrap, @hello, '[', ']']
  end

  def test_replace
    assert_actions_result 'puts(:hi, :world)', [:replace, @hello, ':hi']
  end

  #
  # All other cases, as per doc
  #

  def test_crossing_non_deletions
    check = [
      [:wrap, '(', ')'],
      [:remove],
      [:replace, 'xx'],
    ]
    check.combination(2) do |(action, *args), (action_b, *args_b)|
      next if action == :remove && action_b == :remove
      assert_actions_result :raise,
                            [[action, @hello.join(@comma_space), *args],
                             [action_b, @world.join(@comma_space), *args_b]],
                            diagnostic: <<-DIAGNOSTIC.chomp
(rewriter):1:12: error: the rewriting action on:
(rewriter):1: puts(:hello, :world)
(rewriter):1:            ^~~~~~~~
(rewriter):1:6: error: is crossing that on:
(rewriter):1: puts(:hello, :world)
(rewriter):1:      ^~~~~~~~
DIAGNOSTIC
    end
  end


  def test_crossing_deletions
    assert_actions_result 'puts()',
                          [[:remove, @hello.join(@comma_space)],
                           [:remove, @world.join(@comma_space)]],
                          crossing_deletions: <<-DIAGNOSTIC.chomp
(rewriter):1:12: warning: the deletion of:
(rewriter):1: puts(:hello, :world)
(rewriter):1:            ^~~~~~~~
(rewriter):1:6: warning: is crossing:
(rewriter):1: puts(:hello, :world)
(rewriter):1:      ^~~~~~~~
DIAGNOSTIC
  end

  def test_multiple_actions
    assert_actions_result 'puts({:hello => [:everybody]})',
                          [:replace, @comma_space, ' => '],
                          [:wrap, @hello.join(@world), '{', '}'],
                          [:replace, @world, ':everybody'],
                          [:wrap, @world, '[', ']']
  end

  def test_wraps_same_range
    assert_actions_result 'puts([(:hello)], :world)',
                           [[:wrap, @hello, '(', ')'],
                            [:wrap, @hello, '[', ']']]
  end

  def test_inserts_on_empty_ranges
    assert_actions_result 'puts({x}:hello[y], :world)',
      [:insert_before, @hello.begin, '{'],
      [:replace, @hello.begin, 'x'],
      [:insert_after, @hello.begin, '}'],
      [:insert_before, @hello.end, '['],
      [:replace, @hello.end, 'y'],
      [:insert_after, @hello.end, ']']
  end

  def test_replace_same_range
    assert_actions_result 'puts(:hey, :world)',
                           [[:replace, @hello, ':hi'],
                            [:replace, @hello, ':hey']],
                           different_replacements: <<-DIAGNOSTIC.chomp
(rewriter):1:6: warning: different replacements: :hey vs :hi
(rewriter):1: puts(:hello, :world)
(rewriter):1:      ^~~~~~
DIAGNOSTIC
  end

  def test_swallowed_insertions
    assert_actions_result 'puts(:hi)',
                           [[:wrap, @hello.adjust(begin_pos: 1), '__', '__'],
                            [:replace, @world.adjust(end_pos: -2), 'xx'],
                            [:replace, @hello.join(@world), ':hi']],
                           swallowed_insertions: <<-DIAGNOSTIC.chomp
(rewriter):1:6: warning: this replacement:
(rewriter):1: puts(:hello, :world)
(rewriter):1:      ^~~~~~~~~~~~~~
(rewriter):1:7: warning: swallows some inner rewriting actions:
(rewriter):1: puts(:hello, :world)
(rewriter):1:       ^~~~~  ~~~~
DIAGNOSTIC
  end

  def test_out_of_range_ranges
    rewriter = Parser::Source::TreeRewriter.new(@buf)
    assert_raises(IndexError) { rewriter.insert_before(range(0, 100), 'hola') }
  end

  def test_empty
    rewriter = Parser::Source::TreeRewriter.new(@buf)
    assert_equal true, rewriter.empty?

    # This is a trivial wrap
    rewriter.wrap(range(2,3), '', '')
    assert_equal true, rewriter.empty?

    # This is a trivial deletion
    rewriter.remove(range(2,0))
    assert_equal true, rewriter.empty?

    rewriter.remove(range(2,3))
    assert_equal false, rewriter.empty?
  end

  # splits array into two groups, yield all such possible pairs of groups
  # each_split([1, 2, 3, 4]) yields [1, 2], [3, 4];
  #                            then [1, 3], [2, 4]
  #                                 ...
  #                     and finally [3, 4], [1, 2]
  def each_split(array)
    n = array.size
    first_split_size = n.div(2)
    splitting = (0...n).to_set
    splitting.to_a.combination(first_split_size) do |indices|
      yield array.values_at(*indices),
            array.values_at(*(splitting - indices))
    end
  end

  # Checks that `actions+extra` give the same result when
  # made in order or from subgroups that are later merged.
  # The `extra` actions are always added at the end of the second group.
  #
  def check_all_merge_possibilities(actions, extra, **policy)
    expected = apply(actions + extra, **policy)

    each_split(actions) do |actions_1, actions_2|
      build(actions_1, **policy) do |rewriter_1|
        build(actions_2 + extra, **policy) do |rewriter_2|
          result = rewriter_1.merge(rewriter_2).process
          assert_equal(expected, result,
            "Group 1: #{actions_1.inspect}\n\n" +
            "Group 2: #{(actions_2 + extra).inspect}"
          )
        end
      end
    end
  end

  def test_merge
    check_all_merge_possibilities([
      [:wrap, @whole, '<', '>'],
      [:replace, @comma_space, ' => '],
      [:wrap, @hello, '!', '!'],
      # Following two wraps must have same value as they
      # will be applied in different orders...
      [:wrap, @hello.join(@world), '{', '}'],
      [:wrap, @hello.join(@world), '{', '}'],
      [:remove, @ll],
      [:replace, @world, ':everybody'],
      [:wrap, @world, '[', ']']
    ],
    [ # ... but this one is always going to be applied last (extra)
      [:wrap, @hello.join(@world), '@', '@'],
    ])
  end
end
