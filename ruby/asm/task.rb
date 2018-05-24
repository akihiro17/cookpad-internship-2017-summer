require_relative '../yasm'

def assert iseq, expected
  r = iseq.eval
  if r == expected
    puts "==> OK: #{iseq.label}@#{iseq.path} success."
  else
    puts "!" * 70
    puts "==> NG: #{iseq.label}@#{iseq.path} fails (epxected: #{expected.inspect}, actual: #{r.inspect})."
    exit 1
  end
end

# 1
iseq = YASM.asm label: 'A-1: integer:1' do
  putobject 1
  leave
end

assert iseq, 1

# 1_000_000
iseq = YASM.asm label: 'A-1: integer:1_000_000' do
  putobject 1000000
  leave
end

assert iseq, 1_000_000

# :ok
iseq = YASM.asm label: "A-1': symbol:ok" do
  putobject :ok
  leave
end

assert iseq, :ok

# :ng
iseq = YASM.asm label: "A-1': symbol:ng" do
  putobject :ng
  leave
end

assert iseq, :ng

# "hello"
iseq = YASM.asm label: "A-1'': string:hello" do
  putstring "hello"
  leave
end

assert iseq, "hello"

# a = 1; a
iseq = YASM.asm label: 'A-2: local_variables' do
  putobject 1
  setlocal 1, 0
  getlocal 1, 0
  leave
end

assert iseq, 1

# self
iseq = YASM.asm label: 'A-3: self' do
  putself
  leave
end

assert iseq, self

# nil
iseq = YASM.asm label: 'A-3: nil' do
  putnil
  leave
end

assert iseq, nil

# method call: 1 < 10 #=> true ( 1.<(10) #=> true )
iseq = YASM.asm label: 'A-4: 1.<(10)' do
  putobject 1
  putobject 10
  send :<, 1
  leave
end

assert iseq, true

# method call: p(1) #=> 1
iseq = YASM.asm label: 'A-4: p(1)' do
  putself
  putobject 1
  send :p, 1, YASM::FCALL
  leave
end

assert iseq, 1

# combination: 1 - 2 * 3 #=> -5
# 1.-(2.*(3))
iseq = YASM.asm label: "A-4': 1 - 2 * 3" do
  putobject 1
  putobject 2
  putobject 3
  send :*, 1
  send :-, 1
  leave
end

assert iseq, -5

# combination: a = 10; p(a > 1) #=> true
iseq = YASM.asm label: "A-4': a = 10; p(a > 1)" do
  putobject 10
  setlocal 1, 0

  # main.p
  putself

  # a > 1
  getlocal 1, 0
  putobject 1
  send :>, 1

  # p(a > 1)
  send :p, 1, YASM::FCALL

  leave
end

assert iseq, true

# combination: a = 1; b = 2; c = 3; a - b * c #=> -5
iseq = YASM.asm label: "A-4': a = 1; b = 2; c = 3; a - b * c" do
  putobject 1
  setlocal 1, 0 # a
  putobject 2
  setlocal 2, 0 # b
  putobject 3
  setlocal 3, 0 # c

  getlocal 1, 0 # a
  getlocal 2, 0 # b
  getlocal 3, 0 # c

  send :*, 1
  send :-, 1

  leave
end

assert iseq, -5

# combination: p('foo'.upcase) #=> 'FOO'
iseq = YASM.asm label: "A-4': p('foo'.upcase)" do
  # self
  putself

  # 'foo'.upcase
  putobject 'foo'
  send :upcase, 0

  send :p, 1, YASM::FCALL

  leave
end

assert iseq, 'FOO'

# if statement
# a = 10
# if a > 1
#   p :ok
# else
#   p :ng
# end
iseq = YASM.asm label: 'A-5: if' do
  putobject 10
  setlocal 1, 0

  getlocal 1, 0
  putobject 1
  send :>, 1

  branchunless :ng
  putself
  putobject :ok
  send :p, 1, YASM::FCALL
  jump :fin

  label :ng
  putself
  putobject :ng
  send :p, 1, YASM::FCALL

  label :fin

  leave
end

assert iseq, :ok

# if statement without else (1)
# a = 10
# if a > 1
#   p :ok
# end
iseq = YASM.asm label: "A-5': if_without_else1" do
  putobject 10
  setlocal 1, 0

  getlocal 1, 0
  putobject 1
  send :>, 1

  branchunless :if_else

  putself
  putobject :ok
  send :p, 1, YASM::FCALL
  jump :fin

  label :if_else
  putnil

  label :fin
  leave
end

assert iseq, :ok

# if statement without else (2)
iseq = YASM.asm label: "A-5': if_without_else2" do
  putobject 10
  setlocal 1, 0

  getlocal 1, 0
  putobject 1
  send :>, 1

  branchif :fin

  putself
  putobject :ok
  send :p, 1, YASM::FCALL
  jump :leave

  label :fin
  putnil
  label :leave

  leave
end

assert iseq, nil

# while
# a = 0
# while (a < 10)
#   p a
#   a += 1
# end
# a
iseq = YASM.asm label: "A-6: while" do
  putobject 0
  setlocal 1, 0

  label :begin

  # a < 10
  getlocal 1, 0
  putobject 10
  send :<, 1

  # while
  branchunless :finish

  # p a
  putself
  getlocal 1, 0
  send :p, 1, YASM::FCALL
  pop # discard the result of p

  # a = a + 1
  getlocal 1, 0
  putobject 1
  send :+, 1
  setlocal 1, 0

  # while end
  jump :begin

  label :finish

  getlocal 1, 0

  leave
end

assert iseq, 10

# def foo(); end
iseq = YASM.asm label: "A-7: def:foo()" do
  # methodの実体
  iseq = YASM.asm label: "foo", type: :method do
    putnil
    leave
  end

  # SpecialObject.core#define_method
  putspecialobject 1
  putobject :foo
  putiseq iseq.to_a
  send :"core#define_method", 2
  leave
end

assert iseq, :foo

# def foo(a); a; end; foo(100)
iseq = YASM.asm label: 'A-7: def:foo(a)' do
  # methodの実体
  iseq = YASM.asm label: "foo", type: :method, parameters: [:a] do
    getlocal :a, 0
    leave
  end

  # SpecialObject.core#define_method
  putspecialobject 1
  putobject :foo
  putiseq iseq.to_a
  send :"core#define_method", 2
  pop # discard method symbol

  # foo(100)
  putself
  putobject 100
  send :foo, 1, YASM::FCALL

  leave
end

assert iseq, 100

# def fib(n)
#   if n < 2
#     1
#   else
#     fib(n – 2) + fib(n-1)
#   end
# end
# fib(10)

iseq = YASM.asm label: 'A-7: fib' do

  define_method_macro :fib, parameters: [:n] do
    getlocal :n
    putobject 2
    send :<, 1

    branchunless :else

    label :if
    putobject 1
    jump :end
    label :else

    # fib(n-2)
    putself
    # n - 2
    getlocal :n
    putobject 2
    send :-, 1
    send :fib, 1, YASM::FCALL

    # fib(n-1)
    putself
    # n - 1
    getlocal :n
    putobject 1
    send :-, 1
    send :fib, 1, YASM::FCALL

    send :+, 1

    label :end

    leave
  end
  pop

  putself
  putobject 10
  send :fib, 1, YASM::FCALL
  leave
end

assert iseq, 89

# i = 0
# 2.times do
#   i += 1
# end
# i
iseq = YASM.asm label: "block" do
  blockiseq = YASM.asm label: "block", type: :block do
    getlocal :i, 1
    putobject 1
    send :+, 1
    setlocal :i, 1
    dup
    leave
  end

  putobject 0
  setlocal :i, 0
  putobject 2
  send :times, 0, 0, blockiseq
  leave
end

assert iseq, 2
