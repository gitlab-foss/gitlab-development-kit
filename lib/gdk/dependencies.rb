# frozen_string_literal: true

require 'net/http'
require 'mkmf'

# Make the MakeMakefile logger write file output to null.
module MakeMakefile::Logging
  @logfile = File::NULL
  @quiet = true
end

module GDK
  module Dependencies
    class GitLabVersions
      VersionNotDetected = Class.new(StandardError)

      def ruby_version
        read_gitlab_file('.ruby-version').strip || raise(VersionNotDetected, "Failed to determine GitLab's Ruby version")
      end

      def bundler_version
        Checker.parse_version(read_gitlab_file('Gemfile.lock'), prefix: 'BUNDLED WITH\n +') || raise(VersionNotDetected, "Failed to determine GitLab's Bundler version")
      end

      private

      def read_gitlab_file(filename)
        return local_gitlab_path(filename).read if local_gitlab_path(filename).exist?

        read_remote_file(filename)
      end

      def local_gitlab_path(filename)
        Pathname.new(__dir__).join("../../gitlab/#{filename}").expand_path
      end

      def read_remote_file(filename)
        uri = URI("https://gitlab.com/gitlab-org/gitlab/raw/master/#{filename}")
        Net::HTTP.get(uri)
      rescue SocketError
        abort 'Internet connection is required to set up GDK, please ensure you have an internet connection'
      end
    end

    class Checker
      EXPECTED_GO_VERSION = '1.14'
      EXPECTED_YARN_VERSION = '1.12'
      EXPECTED_NODEJS_VERSION = '12.10'
      EXPECTED_POSTGRESQL_VERSION = '11.7.x'

      attr_reader :error_messages

      def self.parse_version(string, prefix: '')
        string[/#{prefix}((\d+.\d+)(.\d+)*)/, 1]
      end

      def initialize
        @error_messages = []
      end

      def check_all
        check_ruby_version
        check_bundler_version
        check_go_version
        check_nodejs_version
        check_yarn_version
        check_postgresql_version

        check_graphicsmagick_installed
        check_exiftool_installed
        check_minio_installed
        check_runit_installed
      end

      def check_binary(binary)
        find_executable(binary).tap do |result|
          @error_messages << "#{binary} does not exist. You may need to check your PATH or install a missing package." unless result
        end
      end

      def check_ruby_version
        return unless check_binary('ruby')

        actual = Gem::Version.new(RUBY_VERSION)
        expected = Gem::Version.new(GitLabVersions.new.ruby_version)

        @error_messages << require_minimum_version('Ruby', actual, expected) if actual < expected
      end

      def check_bundler_version
        return if bundler_version_ok? || alt_bundler_version_ok?

        @error_messages << <<~BUNDLER_VERSION_NOT_MET
          Please install Bundler version #{expected_bundler_version}.
          gem install bundler -v '= #{expected_bundler_version}'
        BUNDLER_VERSION_NOT_MET
      end

      def bundler_version_ok?
        cmd = Shellout.new("bundle _#{expected_bundler_version}_ --version >/dev/null 2>&1")
        cmd.try_run
        cmd.success?
      end

      def alt_bundler_version_ok?
        # On some systems, most notably Gentoo, Ruby Gems get patched to use a
        # custom wrapper. Because of this, we cannot use the `bundle
        # _$VERSION_` syntax and need to fall back to using `bundle --version`
        # on a best effort basis.
        actual = Shellout.new('bundle --version').try_run
        actual = Checker.parse_version(actual, prefix: 'Bundler version ')

        Gem::Version.new(actual) == Gem::Version.new(expected_bundler_version)
      end

      def check_go_version
        return unless check_binary('go')

        current_version = Checker.parse_version(`go version`, prefix: 'go')

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_GO_VERSION)
        @error_messages << require_minimum_version('Go', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Go', minimum_version: EXPECTED_GO_VERSION)
      end

      def check_nodejs_version
        return unless check_binary('node')

        current_version = Checker.parse_version(`node --version`, prefix: 'v')

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_NODEJS_VERSION)

        @error_messages << require_minimum_version('Node.js', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Node.js', minimum_version: EXPECTED_NODEJS_VERSION)
      end

      def check_yarn_version
        return unless check_binary('yarn')

        current_version = Checker.parse_version(`yarn --version`)

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_YARN_VERSION)

        @error_messages << require_minimum_version('Yarn', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Yarn', minimum_version: expected)
      end

      def check_postgresql_version
        return unless check_binary('psql')

        current_postgresql_version = Checker.parse_version(`psql --version`, prefix: 'psql \(PostgreSQL\) ')

        actual = Gem::Version.new(current_postgresql_version)
        expected = Gem::Version.new(EXPECTED_POSTGRESQL_VERSION)

        @error_messages << require_minimum_version('PostgreSQL', actual, expected) if actual.segments[0] < expected.segments[0]
      end

      def check_graphicsmagick_installed
        @error_messages << missing_dependency('GraphicsMagick') unless system("gm version >/dev/null 2>&1")
      end

      def check_exiftool_installed
        @error_messages << missing_dependency('Exiftool') unless system("exiftool -ver >/dev/null 2>&1")
      end

      def check_minio_installed
        @error_messages << missing_dependency('MinIO') unless system("minio --help >/dev/null 2>&1")
      end

      def check_runit_installed
        @error_messages << missing_dependency('Runit') unless system("which runsvdir >/dev/null 2>&1")
      end

      def require_minimum_version(dependency, actual, expected)
        "#{dependency} version #{actual} detected, please install #{dependency} version #{expected} or higher."
      end

      def missing_dependency(dependency, minimum_version: nil)
        message = "#{dependency} is not installed, please install #{dependency}"
        message += "#{minimum_version} or higher" unless minimum_version.nil?
        message + "."
      end

      private

      def expected_bundler_version
        @expected_bundler_version ||= GitLabVersions.new.bundler_version.freeze
      end
    end
  end
end
