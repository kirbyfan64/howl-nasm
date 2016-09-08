bundle_load = bundle_load
print = print

howl.util.lpeg_lexer ->
  c = capture

  id = (alpha + S'._?')^1 * (alpha + digit + S'_$#@~.?')^0
  ws = c 'whitespace', blank^0
  string_contents = any {
    span "'", "'"
    span '"', '"'
    span '`', '`', '\\'
  }

  identifier = c 'identifier', id

  ul = (c) -> P(c)+P(c\upper!)
  ult = (w) -> [ul c for c in w\gmatch '.']
  uls = (w) -> any ult w
  case_word = (words) ->
    any [sequence ult w for w in *words]

  keyword = c 'keyword', case_word {
    'abs', 'alignb', 'align', 'at', 'byte', 'default', 'db', 'dd', 'do', 'dq',
    'dt', 'dword', 'dw', 'endstruc', 'equ', 'iend', 'incbin', 'istruc',
    'nosplit', 'opsize', 'oword', 'qword', 'rel', 'resb', 'resd', 'reso',
    'resq', 'rest', 'resw', 'resy', 'resz', 'sectalign', 'struc', 'strict',
    'times', 'seq', 'tword', 'word', 'wrt', 'yword', 'zword'
  }

  instrs = bundle_load 'instructions'
  instr = c 'keyword', P (file, pos) ->
    word = file\sub(pos)\match'^%a+'
    if instrs[word]
      pos + #word
    else
      false

  macro = c 'preproc', P'%' * any {
    span '[', ']'
    P'!' * (id + string_contents)^-1
    P'??'
    P'00'
    S'+?0'
    word {
      'arg', 'assign', 'define', 'defstr', 'deftok', 'depend', 'error', 'fatal',
      'ifctx', 'ifdef', 'ifempty', 'ifenv', 'ifidni', 'ifidn', 'ifmacro',
      'iftoken', 'if','include', 'line', 'local', 'macro', 'pathsearch', 'pop',
      'push', 'stacksize', 'strcat', 'strlen', 'substr', 'repl', 'rep', 'rotate',
      'xdefine', 'undef', 'unmacro', 'use', 'warning'
    }
  }

  comment = c 'comment', P';' * scan_until eol

  operator = c 'operator', any {
    S'\\:,()[]+*-/%|^&<>~!@'
    case_word {
      '__float8__', '__float16__', '__float32__', '__float64__', '__float80m__',
      '__float80e__', '__float128l__', '__float128h__',
      '__utf16__', '__utf32__'
    }
  }

  special = c 'special', (P'__USE_' * id * '__') + word {
    '__BITS__', '__DATE_NUM__', '__DATE__', '__FILE__', '__Infinity__',
    '__LINE__', '__NASM_VERSION_ID__', '__NASM_VER__', '__NaN__',
    '__POSIX_TIME__', '__PASS__', '__OUTPUT_FORMAT__', '__QNaN__', '__SNaN__',
    '__TIME_NUM__', '__TIME__', '__UTC_DATE_NUM__', '__UTC_DATE__',
    '__UTC_TIME_NUM__','__UTC_TIME__'
  }

  make_num_set = (chr0, chr1, letters, bare_prefix, dec) ->
    chr = if chr1
      chr0 + chr1
    else
      chr0
    usc = chr + P'_'
    digit = chr * usc^0
    seq = digit^1
    oseq = digit^0
    float_suf = P'.' * oseq
    exp_suf = ul'e' * S'+-'^-1 * seq
    p_suf = ul'p' * S'+-'^-1 * oseq

    id_prefix = P'0' * letters
    id_prefix += bare_prefix * #chr if bare_prefix

    run = seq^-1 * float_suf^-1 * (exp_suf + p_suf)^-1

    if dec
      chr * run * letters^-1
    else
      (id_prefix * chr * run) + (chr0 * run * letters)

  number = c 'number', S'+-'^-1 * any {
    make_num_set R'01', nil, uls'by'
    make_num_set R'07', nil, uls'oq'
    make_num_set R'09', R'af' + R'AF', uls'hx', P'$'
    make_num_set R'09', nil, uls'dt', nil, true
  }

  string = c 'string', string_contents

  any {
    comment
    keyword
    instr
    special
    number
    macro
    operator
    identifier
  }