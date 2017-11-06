require_relative 'test_base'
require_relative 'os_helper'

class FileBombTest < TestBase

  include OsHelper

  def self.hex_prefix
    '1988B'
  end

  def hex_setup
    set_image_name image_for_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DB3', %w( [Alpine]
  file-bomb in C fails to go off
  ) do
    hiker_c = [
      '#include "hiker.h"',
      '#include <stdio.h>',
      '',
      'int answer(void)',
      '{',
      '  for (int i = 0;;i++)',
      '  {',
      '    char filename[42];',
      '    sprintf(filename, "wibble%d.txt", i);',
      '    FILE * f = fopen(filename, "w");',
      '    if (f)',
      '      fprintf(stdout, "fopen() != NULL %s\n", filename);',
      '    else',
      '    {',
      '      fprintf(stdout, "fopen() == NULL %s\n", filename);',
      '      break;',
      '    }',
      '  }',
      '  return 6 * 7;',
      '}'
    ].join("\n")

    in_kata {
      as('salmon') {
        run_cyber_dojo_sh({
          changed_files:{ 'hiker.c' => hiker_c }
        })
      }
    }
    assert_status success
    assert_stderr ''
    lines = stdout.split("\n")

    assert_equal 1, lines.count{ |line|
      line == 'All tests passed'
    }
    assert lines.count{ |line|
      line.start_with? 'fopen() != NULL'
    } > 42
    assert_equal 1, lines.count{ |line|
      line.start_with? 'fopen() == NULL'
    }
  end

end
