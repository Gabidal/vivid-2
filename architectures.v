namespace instructions

namespace shared {
	constant COMPARE = 'cmp'
	constant ADD = 'add'
	constant AND = 'and'
	constant MOVE = 'mov'
	constant NEGATE = 'neg'
	constant SUBTRACT = 'sub'
	constant RETURN = 'ret'
	constant NOP = 'nop'
}

namespace x64 {
	constant EVALUATE_MAX_MULTIPLIER = 8

	constant XOR = 'xor'
	constant EVALUATE = 'lea'
	constant UNSIGNED_CONVERSION_MOVE = 'movzx'
	constant SIGNED_CONVERSION_MOVE = 'movsx'
	constant SIGNED_DWORD_CONVERSION_MOVE = 'movsxd'
	constant SHIFT_LEFT = 'sal'
	constant SIGNED_MULTIPLY = 'imul'
	constant CALL = 'call'
	constant EXCHANGE = 'xchg'

	constant JUMP_ABOVE = 'ja'
	constant JUMP_ABOVE_OR_EQUALS = 'jae'
	constant JUMP_BELOW = 'jb'
	constant JUMP_BELOW_OR_EQUALS = 'jbe'
	constant JUMP_EQUALS = 'je'
	constant JUMP_GREATER_THAN = 'jg'
	constant JUMP_GREATER_THAN_OR_EQUALS = 'jge'
	constant JUMP_LESS_THAN = 'jl'
	constant JUMP_LESS_THAN_OR_EQUALS = 'jle'
	constant JUMP = 'jmp'
	constant JUMP_NOT_EQUALS = 'jne'
	constant JUMP_NOT_ZERO = 'jnz'
	constant JUMP_ZERO = 'jz'

	constant TEST = 'test'
}