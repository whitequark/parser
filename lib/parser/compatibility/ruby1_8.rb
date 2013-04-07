class String
  alias original_percent %

  def %(arg, *args)
    if arg.is_a?(Hash)
      gsub(/%\{(\w+)\}/) do
        arg[$1.to_sym]
      end
    else
      original_percent(arg, *args)
    end
  end
end
