module Parser
  case RUBY_VERSION
  when /^1\.8\./
    if RUBY_VERSION != '1.8.7'
      warn "warning: parser/current is loading parser/ruby18, which implements"
      warn "warning: 1.8.7-compliant syntax, but you are running #{RUBY_VERSION}."
    end

    require 'parser/ruby18'
    CurrentRuby = Ruby18

  when /^1\.9\./
    if RUBY_VERSION != '1.9.3'
      warn "warning: parser/current is loading parser/ruby19, which implements"
      warn "warning: 1.9.3-compliant syntax, but you are running #{RUBY_VERSION}."
    end

    require 'parser/ruby19'
    CurrentRuby = Ruby19

  when /^2\.0\./
    require 'parser/ruby20'
    CurrentRuby = Ruby20
  end
end
