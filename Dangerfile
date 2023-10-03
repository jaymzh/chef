if git.modified_files.include?('Gemfile.lock') && !github.pr_body.include('--conservative')
  failure "Gem/Bundle changes were not documented in the Description."
end
