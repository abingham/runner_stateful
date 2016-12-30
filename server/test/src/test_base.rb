require 'json'
require_relative '../hex_mini_test'
require_relative '../../src/docker_runner'
require_relative '../../src/externals'

class TestBase < HexMiniTest

  def kata_setup
    @image_name = image_for_test
    new_kata
    new_avatar
  end

  def kata_teardown
    old_avatar
    old_kata
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  include Externals
  def runner; @runner ||= DockerRunner.new(self); end

  def pulled?(name = @image_name)
    runner.pulled?(name)
  end

  def pull(name = @image_name)
    runner.pull(name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def new_kata(options = {})
    options[:image_name] = @image_name unless options.key? :image_name
    options[:kata_id   ] = kata_id     unless options.key? :kata_id
    image_name = options[:image_name]
    kata_id    = options[:kata_id   ]
    runner.new_kata(image_name, kata_id)
  end

  def old_kata(options = {})
    options[:kata_id] = kata_id unless options.key? :kata_id
    kata_id = options[:kata_id]
    runner.old_kata(kata_id)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def new_avatar(options = {})
    options[:image_name ] = @image_name unless options.key? :image_name
    options[:kata_id    ] = kata_id     unless options.key? :kata_id
    options[:avatar_name] = avatar_name unless options.key? :avatar_name
    image_name  = options[:image_name ]
    kata_id     = options[:kata_id    ]
    avatar_name = options[:avatar_name]
    runner.new_avatar(image_name, kata_id, avatar_name, files)
  end

  def old_avatar(options = {})
    options[:image_name ] = @image_name unless options.key? :image_name
    options[:kata_id    ] = kata_id     unless options.key? :kata_id
    options[:avatar_name] = avatar_name unless options.key? :avatar_name
    image_name  = options[:image_name ]
    kata_id     = options[:kata_id    ]
    avatar_name = options[:avatar_name]
    runner.old_avatar(image_name, kata_id, avatar_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def runner_run(options = {})
    # don't call this run() as it clashes with MiniTest
    options[:image_name       ] = @image_name unless options.key? :image_name
    options[:kata_id          ] = kata_id     unless options.key? :kata_id
    options[:avatar_name      ] = avatar_name unless options.key? :avatar_name
    options[:deleted_filenames] = []          unless options.key? :deleted_filenames
    options[:changed_files    ] = files       unless options.key? :changed_files
    options[:max_seconds      ] = 10          unless options.key? :max_seconds
    args = []
    args << options[:image_name]
    args << options[:kata_id]
    args << options[:avatar_name]
    args << options[:deleted_filenames]
    args << options[:changed_files]
    args << options[:max_seconds]
    @sss = runner.run(*args)
    [stdout,stderr,status]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sss; @sss; end

  def stdout; sss[:stdout]; end
  def stderr; sss[:stderr]; end
  def status; sss[:status]; end

  def assert_stdout(expected); assert_equal expected, stdout, sss; end
  def assert_stderr(expected); assert_equal expected, stderr, sss; end
  def assert_status(expected); assert_equal expected, status, sss; end

  def assert_stdout_include(text); assert stdout.include?(text), sss; end
  def assert_stderr_include(text); assert stderr.include?(text), sss; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh_no_stderr(script)
    assert_run_succeeds_no_stderr({
      changed_files: { 'cyber-dojo.sh' => script }
    })
  end

  def assert_run_succeeds_no_stderr(options)
    stdout,stderr = assert_run_succeeds(options)
    assert_equal '', stderr, stdout
    stdout
  end

  def assert_run_succeeds(options)
    stdout,stderr,status = runner_run(options)
    assert_equal success, status, [stdout,stderr]
    [stdout,stderr]
  end

  def assert_run_times_out(options)
    stdout,stderr,status = runner_run(options)
    assert_equal timed_out, status, [stdout,stderr]
    [stdout,stderr]
  end

  def assert_exec(cmd)
    stdout,stderr,status = exec(cmd)
    assert_equal success, status, [stdout,stderr]
    [stdout,stderr]
  end

  def exec(cmd, logging = true)
    shell.exec(cmd, logging)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_for_test
    rows = {
      '[C#,NUnit]'      => 'csharp_nunit',
      '[C#,Moq]'        => 'csharp_moq',
      '[gcc,assert]'    => 'gcc_assert',
      '[Java,Cucumber]' => 'java_cucumber_pico',
      '[Alpine]'        => 'gcc_assert',
      '[Ubuntu]'        => 'clangpp_assert'
    }
    row = rows.detect { |key,_| test_name.start_with? key }
    fail 'cannot find image_name from test_name' if row.nil?
    'cyberdojofoundation/' + row[1]
  end

  def files(language_dir = language_dir_from_image_name)
    @files ||= load_files(language_dir)
  end

  def language_dir_from_image_name
    fail '@image_name.nil? so cannot set language_dir' if @image_name.nil?
    @image_name.split('/')[1]
  end

  def load_files(language_dir)
    dir = "/app/start_files/#{language_dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    @image_name = json['image_name']
    Hash[json['visible_filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def user_id(name = 'salmon')
    runner.user_id(name).to_s
  end

  def group
    runner.group
  end

  def sandbox(name = 'salmon')
    runner.sandbox_path(name)
  end

  def success; runner.success; end
  def timed_out; runner.timed_out; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_id; test_id + '0' * (10-test_id.length); end
  def avatar_name; 'salmon'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def invalid_kata_ids
    [
      nil,          # not string
      Object.new,   # not string
      [],           # not string
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789G'  # not 10 hex-chars
    ]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_raises_method_message(method, message, kata_id, avatar_name)
    error = assert_raises(ArgumentError) {
      self.send(method, {
            kata_id:kata_id,
        avatar_name:avatar_name
      })
    }
    assert error.message.start_with?(message), error.message
  end

end
