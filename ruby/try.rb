require_relative 'yasm'

script = <<END_OF_SCRIPT
# insert your favorite Ruby program here.

i = 0
2.times do
  i = i + 1
end
i

END_OF_SCRIPT

YASM.compile_and_disasm(script)
# YASM.compile_and_to_ary(script)
