# https://github.com/injekt/slop/pull/110
class Slop
  def extract_long_flag(objects, config)
    flag = objects.first.to_s
    if flag =~ /\A(?:--?)?[a-zA-Z0-9][a-zA-Z0-9_.-]+\=?\??\z/
      config[:argument] ||= true if flag.end_with?('=')
      config[:optional_argument] = true if flag.end_with?('=?')
      objects.shift
      clean(flag).sub(/\=\??\z/, '')
    end
  end
end
