require_relative 'all_avatars_names'
require_relative 'nearest_ancestors'
require_relative 'null_logger'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require 'timeout'

module DockerRunnerMixIn

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent # For nearest_ancestors()

  def pulled?(image_name)
    image_names.include?(image_name)
  end

  def pull(image_name)
    assert_exec("docker pull #{image_name}")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def user_id(avatar_name)
    assert_valid_name(avatar_name)
    40000 + all_avatars_names.index(avatar_name)
  end

  def home_path(avatar_name)
    "/home/#{avatar_name}"
  end

  def sandbox_path(avatar_name)
    assert_valid_name(avatar_name)
    "#{sandboxes_root}/#{avatar_name}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def group
    'cyber-dojo'
  end

  def gid
    5000
  end

  module_function

  include StringCleaner
  include StringTruncater

  def run_timeout(docker_cmd, max_seconds)
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    pid = Process.spawn(docker_cmd, {
      pgroup:true,
         out:w_stdout,
         err:w_stderr
    })
    begin
      Timeout::timeout(max_seconds) do
        Process.waitpid(pid)
        status = $?.exitstatus
        w_stdout.close
        w_stderr.close
        stdout = truncated(cleaned(r_stdout.read))
        stderr = truncated(cleaned(r_stderr.read))
        [stdout, stderr, status]
      end
    rescue Timeout::Error
      # Kill the [docker exec] processes running
      # on the host. This does __not__ kill the
      # cyber-dojo.sh process running __inside__
      # the docker container. See
      # https://github.com/docker/docker/issues/9098
      Process.kill(-9, pid)
      Process.detach(pid)
      ['', '', 'timed_out']
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def image_names
    cmd = 'docker images --format "{{.Repository}}"'
    stdout,_ = assert_exec(cmd)
    names = stdout.split("\n")
    names.uniq - ['<none']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def alpine_add_group_cmd
    "addgroup -g #{gid} #{group}"
  end

  def ubuntu_add_group_cmd
    "addgroup --gid #{gid} #{group}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def alpine_add_user_cmd(avatar_name)
    # Alpine linux has an existing web-proxy user
    # called squid which I have to work round.
    # See avatar_exists?() in docker_avatar_volume_runner.rb
    home = home_path(avatar_name)
    uid = user_id(avatar_name)
    [ "(deluser #{avatar_name};",
      'adduser',
        '-D',             # don't assign a password
        "-G #{group}",
        "-h #{home}",     # home dir
        '-s /bin/sh',     # shell
        "-u #{uid}",
        avatar_name,
        ')'
    ].join(space)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def ubuntu_add_user_cmd(avatar_name)
    home = home_path(avatar_name)
    uid = user_id(avatar_name)
    [ 'adduser',
        '--disabled-password',
        '--gecos ""',          # don't ask for details
        "--home #{home}",      # home dir
        "--ingroup #{group}",
        "--uid #{uid}",
        avatar_name
    ].join(space)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_valid_id(kata_id)
    unless valid_id?(kata_id)
      fail_kata_id('invalid')
    end
  end

  def valid_id?(kata_id)
    kata_id.class.name == 'String' &&
      kata_id.length == 10 &&
        kata_id.chars.all? { |char| hex?(char) }
  end

  def hex?(char)
    '0123456789ABCDEF'.include?(char)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_valid_name(avatar_name)
    unless valid_avatar?(avatar_name)
      fail_avatar_name('invalid')
    end
  end

  include AllAvatarsNames
  def valid_avatar?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def fail_kata_id(message)
    fail bad_argument("kata_id:#{message}")
  end

  def fail_avatar_name(message)
    fail bad_argument("avatar_name:#{message}")
  end

  def fail_command(message)
    fail bad_argument("command:#{message}")
  end

  def bad_argument(message)
    ArgumentError.new(message)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_exec(cmd)
    stdout,stderr,status = exec(cmd)
    unless status == success
      log << "cmd:#{cmd}"
      log << "status:#{status}"
      log << "stdout:#{stdout}"
      log << "stderr:#{stderr}"
      fail_command(cmd)
    end
    [stdout,stderr]
  end

  def exec(cmd)
    shell.exec(cmd)
  end

  def quiet_exec(cmd)
    shell.exec(cmd, NullLogger.new(self))
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - -

  def sandboxes_root; '/sandboxes'; end
  def success; shell.success; end
  def space; ' '; end

  include NearestAncestors
  def shell; nearest_ancestors(:shell); end
  def  disk; nearest_ancestors(:disk ); end
  def   log; nearest_ancestors(:log  ); end

end
