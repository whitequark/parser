require 'parser/all'

module ParseHelper
  include AST::Sexp

  # Use like this:
  # ```
  # assert_parses(
  #     "10 + 20",
  #   %q{~~~~~~~ expression
  #     |   ^ operator
  #     |~~ expression (lit)
  #     }
  #     s(:send, s(:lit, 10), :+, s(:lit, 20)),
  #     %w(1.8 1.9) # optional
  # )
  # ```
  def assert_parses(code, location, ast, versions=%w(1.8))
    versions.each do |version|
      result = parser_for_ruby_version(version).parse(code)
      assert_equal ast, result,
                   "(#{version}) AST equality"

      parse_location_descriptions(location) \
          do |begin_pos, end_pos, loc_field, ast_path, line|

        astlet = traverse_ast(result, ast_path)

        if astlet.nil?
          # This is a testsuite bug.
          raise "No entity with AST path #{ast_path} in #{result.inspect}"
        end

        assert astlet.location.respond_to?(loc_field),
               "(#{version}) location.respond_to?(#{loc_field.inspect}) for #{line.inspect}"

        range = astlet.location.send(loc_field)

        assert range.is_a?(Parser::SourceRange),
               "(#{version}) #{loc_field}.is_a?(SourceRange) for #{line.inspect}"

        assert_equal begin_pos, range.begin,
                     "(#{version}) begin of #{line.inspect}"

        assert_equal end_pos, range.end,
                     "(#{version}) end of #{line.inspect}"
      end
    end
  end

  def parser_for_ruby_version(version)
    case version
    when '1.8'; Parser::Ruby18
    # when '1.9'; Parser::Ruby19 # not yet
    # when '2.0'; Parser::Ruby20 # not yet
    else raise "Unrecognized Ruby version #{version}"
    end
  end

  LOCATION_DESCRIPTION_RE =
      /^(?<skip>\s*)
       (?<hilight>[~\^]+)
       \s+
       (?<location_field>[a-z]+)
       (\s+\((?<ast_path>[a-z0-9.\/]+)\))?$/x

  def parse_location_descriptions(description)
    unless block_given?
      return to_enum(:parse_location_descriptions, description)
    end

    description.each_line do |line|
      # Remove trailing "     |", if it exists.
      line = line.sub(/^\s*\|/, '').rstrip

      next if line.empty?

      if (match = LOCATION_DESCRIPTION_RE.match(line))
        begin_pos      = match[:skip].length
        end_pos        = begin_pos + match[:hilight].length - 1
        location_field = match[:location_field]

        if match[:ast_path]
          ast_path = match[:ast_path].split('.')
        else
          ast_path = []
        end

        yield begin_pos, end_pos, location_field, ast_path, line
      else
        raise "Cannot parse location description line: #{line.inspect}."
      end
    end
  end

  def traverse_ast(ast, path)
    path.inject(ast) do |astlet, path_component|
      # Split "dstr/2" to :dstr and 1
      type_str, index_str = path_component.split('/')
      type, index = type_str.to_sym, index_str.to_i - 1

      matching_children = \
        astlet.children.select do |child|
          AST::Node === child && child.type == type
        end

      matching_children[index]
    end
  end
end
