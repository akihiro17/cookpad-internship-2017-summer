$label_no = 0
def gen_label
  :"label_#{$label_no+=1}"
end

class NodeVisitor
  def initialize yasm
    @yasm = yasm
  end

  def to_iseq
    @yasm.to_iseq
  end

  def visit node
    node_type = node.class.name.to_s.sub(/Node/, '').downcase
    send("process_#{node_type}", node)
  end

  def process_program node
    visit(node.seq_node)
    @yasm.leave
  end

  def process_sequence node
    nodes = node.nodes.dup
    last_node = nodes.pop

    nodes.each{|n|
      visit(n)
      @yasm.pop
    }

    if last_node
      visit last_node
    else
      @yasm.putnil
    end
  end

  def process_send node
    visit(node.receiver_node)
    node.argument_nodes.each do |argument_node|
      visit(argument_node)
    end

    if node.type == :fcall
      @yasm.send node.method_id, node.argument_nodes.size, YASM::FCALL
    else
      @yasm.send node.method_id, node.argument_nodes.size
    end
  end

  def process_self node
    @yasm.putself
  end

  def process_literal node
    obj = node.obj
    @yasm.putobject obj
  end

  def process_stringliteral node
    obj = node.obj
    @yasm.putobject obj
  end

  def process_nil node
    @yasm.putnil
  end

  def process_if node
    visit(node.cond_node)

    else_label = gen_label
    finish_label = gen_label

    @yasm.branchunless else_label
    visit(node.body_node)
    @yasm.jump finish_label

    @yasm.label else_label
    visit(node.else_node)

    @yasm.label finish_label
  end

  def process_while node
    while_start = gen_label
    while_end = gen_label

    @yasm.label while_start
    visit(node.cond_node)

    @yasm.branchunless while_end
    visit(node.body_node)
    @yasm.pop
    @yasm.jump while_start

    @yasm.label while_end
    @yasm.putnil
  end

  def process_def node
    method_iseq = ast2iseq(node)

    # SpecialObject.core#define_method
    @yasm.putspecialobject 1
    @yasm.putobject node.name
    @yasm.putiseq method_iseq.to_a
    @yasm.send :"core#define_method", 2
  end

  def process_lvarassign node
    value = visit(node.value_node)
    @yasm.dup
    lv = 0
    while (scope && !scope.lookup_local(node.lvar_id))
      lv += 1
      scope = @yasm.parent
    end
    @yasm.setlocal node.lvar_id, lv
  end

  def process_lvar node
    scope = @yasm
    lv = 0
    while (scope && !scope.lookup_local(node.lvar_id))
      lv += 1
      scope = @yasm.parent
    end
    p "lv: #{lv}"
    @yasm.getlocal node.lvar_id, lv
  end

  def process_methodaddblock node
    pp node.block_node.nodes
    blockiseq = ast2iseq(node.block_node.nodes, @yasm)
    raise "unsup"
  end
end

def ast2iseq node, parent = nil
  if DefNode === node
    yasm = YASM.new label: node.name.to_s, type: :method, parameters: node.parameters, parent: parent
    node = node.body
  else
    yasm = YASM.new parent: parent
  end
  visitor = NodeVisitor.new(yasm)
  visitor.visit node
  visitor.to_iseq
end
