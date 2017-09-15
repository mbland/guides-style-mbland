require_relative '../lib/jekyll-theme-guides-mbland/repository'

require 'fileutils'
require 'minitest/autorun'
require 'stringio'

module JekyllThemeGuidesMbland
  module RepositoryTestHelper
    attr_reader :testdir, :repo_dir, :outstream

    def setup
      @testdir = Dir.mktmpdir
      @repo_dir = File.join testdir, 'guide-repo'
      FileUtils.mkdir_p repo_dir
      @outstream = StringIO.new
    end

    def teardown
      FileUtils.rm_rf(testdir, secure: true)
    end

    def map_files_to_repo_dir(filenames)
      filenames.map { |filename| File.join repo_dir, filename }
    end

    def template_files
      @template_files ||=
        begin
          FileUtils.mkdir_p File.join(repo_dir, '_pages')
          FileUtils.mkdir_p File.join(repo_dir, 'images')
          map_files_to_repo_dir TEMPLATE_FILES
        end
    end

    def nontemplate_files
      @nontemplate_files ||= map_files_to_repo_dir(%w[foo bar baz])
    end

    def write_all_files
      (template_files + nontemplate_files).each do |file_name|
        FileUtils.mkdir_p(File.dirname(file_name))
        File.write(file_name, '')
      end
    end

    GO_SCRIPT_BEFORE = <<GO_SCRIPT.freeze
extend GoScript
check_ruby_version '2.1.5'

command_group :dev, 'Development commands'

def_command :update_nav, 'Update the \'navigation:\' data in _config.yml' do
  JekyllThemeGuidesMbland.update_navigation_configuration Dir.pwd
end

def_command(
  :create_repo, 'Remove template files and create a new Git repository') do
  JekyllThemeGuidesMbland.clear_template_files_and_create_new_repository Dir.pwd
end

def_command :update_theme, 'Update the jekyll-theme-guides-mbland gem' do
  exec_cmd 'bundle update --source jekyll-theme-guides-mbland'
end
execute_command ARGV
GO_SCRIPT

    GO_SCRIPT_AFTER = <<GO_SCRIPT.freeze
extend GoScript
check_ruby_version '2.1.5'

command_group :dev, 'Development commands'

def_command :update_nav, 'Update the \'navigation:\' data in _config.yml' do
  JekyllThemeGuidesMbland.update_navigation_configuration Dir.pwd
end

def_command :update_theme, 'Update the jekyll-theme-guides-mbland gem' do
  exec_cmd 'bundle update --source jekyll-theme-guides-mbland'
end
execute_command ARGV
GO_SCRIPT

    def write_go_script(content)
      File.write File.join(repo_dir, 'go'), content
    end

    def read_go_script
      File.read File.join(repo_dir, 'go')
    end

    # rubocop:disable MethodLength
    def create_initial_repo(logfile)
      Dir.chdir repo_dir do
        logfile.puts '*** Creating initial repository.'
        write_all_files
        write_go_script GO_SCRIPT_BEFORE
        JekyllThemeGuidesMbland.exec_cmd_capture_output 'git init', logfile
        JekyllThemeGuidesMbland.exec_cmd_capture_output 'git add .', logfile
        JekyllThemeGuidesMbland.exec_cmd_capture_output(
          'git config user.email "test@example.com"', logfile
        )
        JekyllThemeGuidesMbland.exec_cmd_capture_output(
          'git config user.name "Test User"', logfile
        )
        JekyllThemeGuidesMbland.exec_cmd_capture_output(
          'git commit -m "original repo"', logfile
        )
      end
    rescue SystemExit => e
      flunk("Exited with status: #{e.status}\n" \
        "Logfile contents: #{File.read(logfile)}")
    end
    # rubocop:enable MethodLength
  end

  class RemoveTemplateFilesTest < ::Minitest::Test
    include RepositoryTestHelper

    def test_empty_repo_dir_should_not_raise
      JekyllThemeGuidesMbland.remove_template_files repo_dir, outstream
    end

    def test_remove_all_template_files
      write_all_files
      JekyllThemeGuidesMbland.remove_template_files repo_dir, outstream
      assert(template_files.none? { |file| File.exist? file })
      assert(nontemplate_files.all? { |file| File.exist? file })
    end
  end

  class DeleteCreateRepoCommandFromGoScriptTest < ::Minitest::Test
    include RepositoryTestHelper

    def test_remove_create_repo_command
      write_go_script RepositoryTestHelper::GO_SCRIPT_BEFORE
      JekyllThemeGuidesMbland.delete_create_repo_command_from_go_script(
        repo_dir, outstream
      )
      assert_equal RepositoryTestHelper::GO_SCRIPT_AFTER, read_go_script
    end

    def test_create_repo_command_removal_should_be_idemptoent
      write_go_script RepositoryTestHelper::GO_SCRIPT_AFTER
      JekyllThemeGuidesMbland.delete_create_repo_command_from_go_script(
        repo_dir, outstream
      )
      assert_equal RepositoryTestHelper::GO_SCRIPT_AFTER, read_go_script
    end
  end

  class ClearTemplateFilesAndCreateNewRepositoryTest < ::Minitest::Test
    include RepositoryTestHelper

    def test_clear_template_files_and_create_new_repository_test
      log_path = File.join testdir, 'new-repo.log'
      open(log_path, 'w') do |logfile|
        logfile.sync = true
        create_initial_repo logfile
        logfile.puts LOG_TAIL_MARKER
        JekyllThemeGuidesMbland.clear_template_files_and_create_new_repository(
          repo_dir, logfile
        )
      end
      assert_expected_final_repository_state log_path
    end

    def assert_expected_final_repository_state(log_path)
      assert_repository_file_system_state
      assert_log_tail_matches_expected log_path
      assert_new_repo_has_nontemplate_files_staged_for_commit
    rescue StandardError => e
      puts("Log contents: #{File.read(log_path)}")
      raise e
    end

    def assert_repository_file_system_state
      assert(template_files.none? { |file| File.exist? file })
      assert(nontemplate_files.all? { |file| File.exist? file })
      assert_equal(GO_SCRIPT_AFTER, read_go_script)
    end

    def assert_log_tail_matches_expected(log_path)
      log = File.read log_path
      begin_tail = log.index LOG_TAIL_MARKER
      refute_nil begin_tail, 'LOG_TAIL_MARKER not found'
      log_tail = log[begin_tail + LOG_TAIL_MARKER.size + 1..-1]
      assert_equal log_tail(repo_dir), log_tail
    end

    def log_tail(repo_dir)
      # On some systems, repo_dir may be a symlink, but git will print the
      # real path.
      format(LOG_TAIL, Dir.glob(File.realpath(repo_dir)).first)
    end

    LOG_TAIL_MARKER = '*** Clearing template files and ' +
      'creating new repository.'.freeze
    LOG_TAIL = <<LOG_TAIL.freeze
Clearing Guides Template files.
Removing `:create_repo` command from the `./go` script.
Removing old git repository.
Creating a new git repository.
Initialized empty Git repository in %s/.git/
Creating mbland-pages branch.
Switched to a new branch 'mbland-pages'
Adding files for initial commit.
All done! Run 'git commit' to create your first commit.
LOG_TAIL

    def assert_new_repo_has_nontemplate_files_staged_for_commit
      log_path = File.join testdir, 'staged-files.log'
      open(log_path, 'w') do |logfile|
        logfile.sync = true
        Dir.chdir repo_dir do
          JekyllThemeGuidesMbland.exec_cmd_capture_output(
            'git status -s', logfile
          )
        end
      end
      assert_equal STAGED_FILES_STATUS, File.read(log_path)
    end

    STAGED_FILES_STATUS = <<STAGED_FILES_STATUS.freeze
A  bar
A  baz
A  foo
A  go
STAGED_FILES_STATUS
  end
end
