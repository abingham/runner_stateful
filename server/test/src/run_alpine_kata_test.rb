require_relative 'test_base'
require_relative 'os_helper'

class RunAlpineKataTest < TestBase

  include OsHelper

  def self.hex_prefix
    '89079'
  end

  def hex_setup
    kata_setup
  end

  def hex_teardown
    kata_teardown
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CA0', %w( [Alpine]
  image is indeed based on Alpine
  ) do
    etc_issue = assert_docker_run 'cat /etc/issue'
    assert etc_issue.include?('Alpine'), etc_issue
  end

end
