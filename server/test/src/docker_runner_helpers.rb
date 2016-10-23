
require_relative './null_logger'
require 'json'

# TODO?
# expose container's cid and ensure [docker rm #{cid}]
# happens in external_teardown

module DockerRunnerHelpers # mix-in

  module_function

  def external_setup
    assert_equal 'ExternalSheller', shell.class.name
    ENV[env_name('log')] = 'NullLogger'
    @rm_volume = ''
  end

  def external_teardown
    remove_volume(@rm_volume) unless @rm_volume == ''
  end

  def runner_start
    output, exit_status = runner.start(kata_id, avatar_name)
    assert_equal success, exit_status
    @rm_volume = output.strip
  end

  def language_files(dir)
    dir = "/app/test/src/language_start_files/#{dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    @image_name = json['image_name']
    Hash[json['filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
  end

  def runner_run(changed_files, max_seconds = 10, delete_filenames = [])
    output = runner.run(
      @image_name,
      kata_id,
      avatar_name,
      max_seconds,
      delete_filenames,
      changed_files)
  end

  def remove_volume(name)
    # docker_runner.sh does [docker rm --force ${cid}] in a child process.
    # This has a race condition so you need to wait
    # until the container (which has the volume mounted)
    # is 'actually' removed before you can remove the volume.
    100.times do
      output, exit_status = exec("docker volume rm #{name} 2>&1")
      break if exit_status == success
    end
  end

  def exec(command)
    output, exit_success = shell.exec(command)
    return [output, exit_success]
  end

  def runner; DockerRunner.new(self); end
  def success; 0; end
  def kata_id; test_id; end
  def avatar_name; 'salmon'; end
  def volume_name; 'cyber_dojo_' + kata_id + '_' + avatar_name; end

  include Externals # for shell

end
