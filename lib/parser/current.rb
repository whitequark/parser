module Parser
  class << self
    def warn_syntax_deviation(feature, version)
      warn "warning: parser/current is loading #{feature}, which recognizes"
      warn "warning: #{version}-compliant syntax, but you are running #{RUBY_VERSION}."
    end
    private :warn_syntax_deviation
  end

  case RUBY_VERSION
  when /^1\.8\./
    if RUBY_VERSION != '1.8.7'
      warn_syntax_deviation 'parser/ruby18', '1.8.7'
    end

    require 'parser/ruby18'
    CurrentRuby = Ruby18

  when /^1\.9\./
    if RUBY_VERSION != '1.9.3'
      warn_syntax_deviation 'parser/ruby19', '1.9.3'
    end

    require 'parser/ruby19'
    CurrentRuby = Ruby19

  when /^2\.0\./
    require 'parser/ruby20'
    CurrentRuby = Ruby20

  when /^2\.1\./
    require 'parser/ruby21'
    CurrentRuby = Ruby21

  else # :nocov:
    raise NotImplementedError, "Parser does not support parsing Ruby #{RUBY_VERSION}"
  end
end
