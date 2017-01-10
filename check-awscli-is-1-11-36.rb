match = `aws --version 2>&1`.match(%r{^aws-cli/([0-9]+).([0-9]+).([0-9]+) })
if match
  if match[1].to_i < 1 || (match[1].to_i == 1 && (match[2].to_i < 11 || match[2].to_i == 11 && match[3].to_i < 36))
    raise "Please run 'pip install --upgrade awscli'; this will upgrade aws client-line tool to version 1.11.36 or higher"
  end
else
  raise "Please install aws client-line tool by running 'pip install awscli'"
end
