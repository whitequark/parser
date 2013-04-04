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
  def assert_parses(code, source_maps, ast, versions=%w(1.8))
    source_file = Parser::Source::Buffer.new('(assert_parses)')
    source_file.source = code

    versions.each do |version|
      parser     = parser_for_ruby_version(version)
      parsed_ast = parser.parse(source_file)

      assert_equal ast, parsed_ast,
                   "(#{version}) AST equality"

      parse_source_map_descriptions(source_maps) \
          do |begin_pos, end_pos, map_field, ast_path, line|

        astlet = traverse_ast(parsed_ast, ast_path)

        if astlet.nil?
          # This is a testsuite bug.
          raise "No entity with AST path #{ast_path} in #{parsed_ast.inspect}"
        end

        assert astlet.source_map.respond_to?(map_field),
               "(#{version}) source_map.respond_to?(#{map_field.inspect}) for #{line.inspect}"

        range = astlet.source_map.send(map_field)

        assert range.is_a?(Parser::Source::Range),
               "(#{version}) #{map_field}.is_a?(Source::Range) for #{line.inspect}"

        assert_equal begin_pos, range.begin,
                     "(#{version}) begin of #{line.inspect}"

        assert_equal end_pos, range.end,
                     "(#{version}) end of #{line.inspect}"
      end
    end
  end

  def parser_for_ruby_version(version)
    case version
    when '1.8'; Parser::Ruby18.new
    # when '1.9'; Parser::Ruby19 # not yet
    # when '2.0'; Parser::Ruby20 # not yet
    else raise "Unrecognized Ruby version #{version}"
    end
  end

  SOURCE_MAP_DESCRIPTION_RE =
      /^(?<skip>\s*)
       (?<hilight>[~\^]+)
       \s+
       (?<source_map_field>[a-z]+)
       (\s+\((?<ast_path>[a-z0-9.\/]+)\))?$/x

  def parse_source_map_descriptions(descriptions)
    unless block_given?
      return to_enum(:parse_source_map_descriptions, descriptions)
    end

    descriptions.each_line do |line|
      # Remove trailing "     |", if it exists.
      line = line.sub(/^\s*\|/, '').rstrip

      next if line.empty?

      if (match = SOURCE_MAP_DESCRIPTION_RE.match(line))
        begin_pos        = match[:skip].length
        end_pos          = begin_pos + match[:hilight].length - 1
        source_map_field = match[:source_map_field]

        if match[:ast_path]
          ast_path = match[:ast_path].split('.')
        else
          ast_path = []
        end

        yield begin_pos, end_pos, source_map_field, ast_path, line
      else
        raise "Cannot parse source map description line: #{line.inspect}."
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
