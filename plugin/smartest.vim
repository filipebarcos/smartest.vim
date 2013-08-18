" This file uses ideas from Gary Bernhardt for caching the latest test file,
" but adds a lot of other goodies.
"
" Some mappings I recommend:
"
" map <leader>t :call RunTestFile()<cr>
" map <leader>r :call RunNearestTest()<cr>
"

" RunTestFile()
"
" Runs all tests in the current test file.
"
" If the current file is a test file, it caches its path and runs the tests.
" If the current file is NOT a test file, it runs the last cached test path.
" This way, you don't need to keep the test file opened.
"
" Some of the strings we use to define if it's a test file:
"
"   \(.feature\|_spec.rb\|_test.rb\|_test.js\|_spec.js\)
"
function! RunTestFile(...)
  if a:0
    let command_suffix = a:1
  else
    let command_suffix = ""
  endif

  " Run the tests for the previously-marked file.
  let in_test_file = match(expand("%"), '\(.feature\|_spec.rb\|_test.rb\|_test.js\|_spec.js\)')

  if in_test_file >= 0
    call SetTestFile(command_suffix)
  elseif !exists("t:grb_test_file")
    :echo "Vim: I don't know what file to test :("
    return
  end

  call RunTests(t:grb_test_file . t:grb_test_line)
endfunction

" RunNearestTest()
"
" Same as RunTestFile(), except that it'll append the current line number to
" the path, so that you can run a single test.
"
" For example, in RSpec, `rspec test_path:12` will run only the spec under
" line 12.
"
" We try to find the same for Minitest tests.
function! RunNearestTest()
  let spec_line_number = line('.')
  call RunTestFile(":" . spec_line_number)
endfunction

function! SetTestFile(...)
  " Set the spec file that tests will be run for.
  if a:0 && a:1 != ""
    let t:grb_test_line = a:1
  else
    let t:grb_test_line = ""
  endif

  let t:grb_test_file = @%
endfunction

function! RunTests(filename)

  " Save the current file and run tests for the given filename
  :w
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo

  let isolated_spec = match(a:filename, ':\d\+$') > 0
  let cursor_line = substitute(matchstr(a:filename, ':\d\+$'), ":", "", "")

  " JAVASCRIPT
  if match(a:filename, '\(._test.js\|_spec.js\)') >= 0

    let filename_for_spec = substitute(a:filename, "spec/javascripts/", "", "")
    "Konacha
    if filereadable("Gemfile") && match(readfile("Gemfile"), "konacha") >= 0

      " Konacha with Zeus
      if filereadable("zeus.json")
        :silent !echo "Konacha with zeus"
        exec ":!zeus rake konacha:run SPEC=" . filename_for_spec

      " Konacha with bundle exec
      else
        :silent !echo "Konacha with bundle exec"
        exec ":!bundle exec rake konacha:run SPEC=" . filename_for_spec
      endif

    " Everything else (QUnit)
    else
      "Rake
      :silent !echo "Javascript test, running rake"
      exec ":!rake"
    endif

  " RUBY
  elseif match(a:filename, '\(._test.rb\|_spec.rb\)') >= 0

    let filename_without_line_number = substitute(a:filename, ':\d\+$', '', '')
    " Minitest?
    if match(a:filename, '\(_test.rb\)') != -1

      let ruby_command = ":!ruby -I"
      let dependencies_path = "lib/"

      " Rails framework codebase itself?
      "
      " Tests in Rails have different dependencies that we have to check
      let rails_framework = ""
      if globpath(".", "rails.gemspec") > -1
        let rails_framework = substitute(a:filename, '/test/.*', '', '')
        let dependencies_path = rails_framework . "/lib:" . rails_framework . "/test"
      endif

      " Running isolated test
      "
      " Let's find out what's the current test
      let test_method = ""
      if isolated_spec > 0
        let current_line = cursor_line
        while current_line > cursor_line - 50
          " matches something like 'def test_form_for', then removes 'def '
          let line_string = GetLineFromFile(current_line, filename_without_line_number)
          let test_method = matchstr(line_string, 'def test_.*')
          let test_method = substitute(test_method, 'def ', '', '')

          " If it finds a test method, gets out of the loop
          if test_method != ""
            break
          endif
          " We go backwards until we find `def test_.*`
          let current_line -= 1
        endwhile
      endif

      if rails_framework != ""
        :silent !echo "Testing rails/rails project"
      endif

      if test_method != ""
        :exec ":silent !echo Running isolated test: " . test_method
      else
        :silent !echo "Running all tests"
      endif

      let test_command = ruby_command
      let test_command = test_command . " " . dependencies_path
      let test_command = test_command . " " . filename_without_line_number
      if test_method != ""
        let test_command = test_command . " -n " . test_method
      endif

      exec test_command

    " Bundler
    elseif match(readfile(filename_without_line_number), '\("spec_helper\|''spec_helper\|capybara_helper\|acceptance_spec_helper\|acceptance_helper\)') >= 0

      " Spring (gem like Zeus, to make things faster)
      if match(system('spring status'), 'Spring is running') >= 0
        :silent !echo "Using Spring"
        exec ":!spring rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename

      " Zeus
      elseif filereadable("zeus.json") && filereadable("Gemfile")
        :silent !echo "Using zeus"
        exec ":!zeus rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename

      " bundle exec
      elseif filereadable("Gemfile")
        :silent !echo "Using bundle exec"
        exec ":!bundle exec rspec --color --order random " . a:filename

      " pure rspec
      else
        :silent !echo "Using vanilla rspec"
        exec ":!rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
      end

    " Everything else
    else
      :silent !echo "Using vanilla rspec outside Rails"
      exec ":!rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
    end
  end
endfunction

function! GetLineFromFile(line, filename)
  return system('sed -n ' . a:line . 'p ' . a:filename)
endfunction
