require 'parser/all'

module ParseHelper
  include AST::Sexp

  ALL_VERSIONS = %w(1.8)

  def setup
    @diagnostics = []

    super if defined?(super)
  end

  def parser_for_ruby_version(version)
    case version
    when '1.8'; parser = Parser::Ruby18.new
    # when '1.9'; parser = Parser::Ruby19.new # not yet
    # when '2.0'; parser = Parser::Ruby20.new # not yet
    else raise "Unrecognized Ruby version #{version}"
    end

    parser.diagnostics.consumer = lambda do |diagnostic|
      @diagnostics << diagnostic
    end

    parser
  end

  def with_versions(code, versions)
    versions.each do |version|
      @diagnostics.clear

      parser = parser_for_ruby_version(version)
      yield version, parser
    end
  end

  def assert_source_range(begin_pos, end_pos, range, version, what)
    assert range.is_a?(Parser::Source::Range),
           "(#{version}) is_a?(Source::Range) for #{what}"

    assert_equal begin_pos, range.begin,
                 "(#{version}) begin of #{what}"

    assert_equal end_pos, range.end,
                 "(#{version}) end of #{what}"
  end

  # Use like this:
  # ```
  # assert_parses(
  #   s(:send, s(:lit, 10), :+, s(:lit, 20))
  #   %q{10 + 20},
  #   %q{~~~~~~~ expression
  #     |   ^ operator
  #     |     ~~ expression (lit)
  #     },
  #     %w(1.8 1.9) # optional
  # )
  # ```
  def assert_parses(ast, code, source_maps='', versions=ALL_VERSIONS)
    with_versions(code, versions) do |version, parser|
      source_file = Parser::Source::Buffer.new('(assert_parses)')
      source_file.source = code

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

        next # TODO skip location checking

        assert astlet.source_map.respond_to?(map_field),
               "(#{version}) source_map.respond_to?(#{map_field.inspect}) for:\n#{parsed_ast.inspect}"

        range = astlet.source_map.send(map_field)

        assert_source_range(begin_pos, end_pos, range, version, line.inspect)
      end
    end
  end

  # Use like this:
  # ```
  # assert_diagnoses(
  #   [:warning, :ambiguous_prefix, { prefix: '*' }],
  #   %q{foo *bar},
  #   %q{    ^ location
  #     |     ~~~ highlights (0)})
  # ```
  def assert_diagnoses(diagnostic, code, source_maps='', versions=ALL_VERSIONS)
    with_versions(code, versions) do |version, parser|
      source_file = Parser::Source::Buffer.new('(assert_diagnoses)')
      source_file.source = code

      begin
        parser = parser.parse(source_file)
      rescue Parser::SyntaxError
        # do nothing; the diagnostic was reported
      end

      # Remove this `if' when no diagnostics fail to render.
      if @diagnostics.count != 1
        assert_equal 1, @diagnostics.count,
                     "(#{version}) emits a single diagnostic, not\n" \
                     "#{@diagnostics.map(&:render).join("\n")}"
      end

      emitted_diagnostic = @diagnostics.first

      level, kind, substitutions = diagnostic
      message = Parser::ERRORS[kind] % substitutions

      assert_equal level, emitted_diagnostic.level
      assert_equal message, emitted_diagnostic.message

      parse_source_map_descriptions(source_maps) \
          do |begin_pos, end_pos, map_field, ast_path, line|

        next # TODO skip location checking

        case map_field
        when 'location'
          assert_source_range begin_pos, end_pos,
                              emitted_diagnostic.location,
                              version, "location"

        when 'highlights'
          index = ast_path.first.to_i

          assert_source_range begin_pos, end_pos,
                              emitted_diagnostic.highlights[index],
                              version, "#{index}th highlight"

        else
          raise "Unknown diagnostic range #{map_field}"
        end
      end
    end
  end

  SOURCE_MAP_DESCRIPTION_RE =
      /^(?<skip>\s*)
       (?<hilight>[~\^]+)
       \s+
       (?<source_map_field>[a-z]+)
       (\s+\((?<ast_path>[a-z_.\/0-9]+)\))?$/x

  def parse_source_map_descriptions(descriptions)
    unless block_given?
      return to_enum(:parse_source_map_descriptions, descriptions)
    end

    descriptions.each_line do |line|
      # Remove leading "     |", if it exists.
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
