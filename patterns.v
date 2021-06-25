namespace parser

Pattern CommandPattern {
	constant INSTRUCTION = 0

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 2
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		instruction = tokens[INSTRUCTION].(KeywordToken).keyword
		=> instruction == Keywords.STOP or instruction == Keywords.CONTINUE or instruction == Keywords.RETURN
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		instruction = tokens[INSTRUCTION].(KeywordToken).keyword
		if instruction == Keywords.RETURN => ReturnNode(none as Node, tokens[INSTRUCTION].position)
		=> CommandNode(instruction, tokens[INSTRUCTION].position)
	}
}

Pattern AssignPattern {
	constant DESTINATION = 0
	constant OPERATOR = 1

	init() {
		# Pattern: $name = ...
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[OPERATOR].match(Operators.ASSIGN)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Do not remove the assign operator after building the tokens
		state.end--

		destination = tokens[DESTINATION] as IdentifierToken
		name = destination.value

		if not context.is_variable_declared(name) {
			# Ensure the name is not reserved
			if name == SELF_POINTER_IDENTIFIER or name == LAMBDA_SELF_POINTER_IDENTIFIER {
				state.error = Status(destination.position, String('Can not declare variable with name ') + name)
				=> none as Node
			}

			# Determine the category and the modifiers of the variable
			is_constant = context.parent == none
			category = VARIABLE_CATEGORY_MEMBER

			if not context.is_type {
				if is_constant { category = VARIABLE_CATEGORY_GLOBAL }
				else { category = VARIABLE_CATEGORY_LOCAL }
			}

			modifiers = MODIFIER_DEFAULT
			if is_constant { modifiers |= MODIFIER_CONSTANT }

			# All variables in namespaces are static
			if context.is_namespace {
				modifiers |= MODIFIER_STATIC
			}

			variable = Variable(context, none as Type, category, name, modifiers)
			variable.position = destination.position

			context.declare(variable)

			=> VariableNode(variable, destination.position)
		}

		variable = context.get_variable(name)

		if variable.is_member {
			self = common.get_self_pointer(context, destination.position)
			=> LinkNode(self, VariableNode(variable, destination.position), destination.position)
		}

		=> VariableNode(variable, destination.position)
	}
}

Pattern FunctionPattern {
	constant FUNCTION = 0
	constant BODY = 2

	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 20
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[FUNCTION] as FunctionToken
		blueprint = tokens[BODY] as ParenthesisToken

		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint.tokens, descriptor.position, blueprint.end)
		
		result = descriptor.get_parameters(function)
		if not (result has parameters) {
			state.error = Status(result.value as String)
			=> none as Node
		}

		function.parameters.add_range(parameters)

		conflict = context.declare(function)
		if conflict != none {
			state.error = Status(descriptor.position, 'Function conflicts with another function')
			=> none as Node
		}

		=> FunctionDefinitionNode(function, descriptor.position)
	}
}

Pattern OperatorPattern {
	constant LEFT = 0
	constant OPERATOR = 2
	constant RIGHT = 4

	init() {
		# Pattern: ... [\n] $operator [\n] ...
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OBJECT)

		priority = PRIORITY_ALL
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[OPERATOR].(OperatorToken).operator.priority == priority
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		token = tokens[OPERATOR]

		=> OperatorNode(token.(OperatorToken).operator, token.position).set_operands(parse(context, tokens[LEFT]), parse(context, tokens[RIGHT]))
	}
}

Pattern TypePattern {
	constant NAME = 0
	constant BODY = 2

	init() {
		# Pattern: $name [\n] {...}
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 22
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME].(IdentifierToken)
		body = tokens[BODY].(ParenthesisToken)

		type = Type(context, name.value, MODIFIER_DEFAULT, name.position)

		=> TypeDefinitionNode(type, body.tokens, name.position)
	}
}

Pattern ReturnPattern {
	constant RETURN = 0
	constant VALUE = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[RETURN].match(Operators.HEAVY_ARROW)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> ReturnNode(parser.parse(context, tokens[VALUE]), tokens[RETURN].position)
	}
}

Pattern VariableDeclarationPattern {
	constant NAME = 0
	constant COLON = 1

	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[COLON].match(Operators.COLON) and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken

		if context.is_local_variable_declared(name.value) {
			state.error = Status(name.position, 'Variable already exists')
			=> none as Node
		}

		if name.value == SELF_POINTER_IDENTIFIER or name.value == LAMBDA_SELF_POINTER_IDENTIFIER {
			state.error = Status(name.position, 'Can not declare variable, since the name is reserved')
			=> none as Node
		}

		type = common.read_type(context, tokens, COLON + 1)

		is_constant = context.parent == none

		# Determine the variable category
		category = VARIABLE_CATEGORY_MEMBER

		if not context.is_type {
			if is_constant { category = VARIABLE_CATEGORY_GLOBAL }
			else { category = VARIABLE_CATEGORY_LOCAL }
		}

		# Determine the modifiers of the variable
		modifiers = MODIFIER_DEFAULT
		if is_constant { modifiers |= MODIFIER_CONSTANT }
		if context.is_namespace { modifiers |= MODIFIER_STATIC }

		variable = Variable(context, type, category, name.value, modifiers)
		variable.position = tokens[NAME].position

		context.declare(variable)

		=> VariableNode(variable, name.position)
	}
}

Pattern IfPattern {
	constant KEYWORD = 0
	constant CONDITION = 1
	constant BODY = 2

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)

		priority = 1
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		keyword = tokens[KEYWORD].(KeywordToken).keyword
		if keyword != Keywords.IF and keyword != Keywords.ELSE => false

		# Try to consume curly brackets
		next = state.peek()
		if next == none => false
		if next.match(`{`) state.consume()

		=> true
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		condition = parser.parse(environment, tokens[CONDITION])
		start = tokens[KEYWORD].position
		end = none as Position

		body = none as List<Token>
		last = tokens[tokens.size - 1]

		context = Context(environment, NORMAL_CONTEXT)
		
		if last.match(`{`) {
			body = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			body = List<Token>()
			error = common.consume_block(state, body)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				=> none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		if tokens[KEYWORD].(KeywordToken).keyword == Keywords.IF => IfNode(context, condition, node, start, end)
		=> ElseIfNode(context, condition, node, start, end)
	}
}

Pattern ElsePattern {
	constant ELSE = 0

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)

		priority = 1
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[ELSE].(KeywordToken).keyword != Keywords.ELSE => false
		next = state.peek()
		if next == none => false
		if next.match(`{`) state.consume()
		=> true
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		start = tokens[ELSE].position
		end = none as Position

		body = none as List<Token>
		last = tokens[tokens.size - 1]

		context = Context(environment, NORMAL_CONTEXT)
		
		if last.match(`{`) {
			body = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			body = List<Token>()
			error = common.consume_block(state, body)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				=> none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		=> ElseNode(context, node, start, end)
	}
}

Pattern LinkPattern {
	constant STANDARD_TOKEN_COUNT = 5

	constant LEFT = 0
	constant OPERATOR = 2
	constant RIGHT = 4

	init() {
		# Pattern: ... [\n] . [\n] ...
		path.add(TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_DYNAMIC)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_DYNAMIC)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the operator is the dot operator
		if not tokens[OPERATOR].match(Operators.DOT) => false
		# Try to consume template arguments
		if tokens[RIGHT].match(TOKEN_TYPE_IDENTIFIER) {
			# TODO: Support template arguments
		}

		=> true
	}

	private build_template_function_call() {
		abort('Template function call is not supported yet')
		=> none as LinkNode
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		# When there are more tokens than the standard count, it means a template function has been consumed
		if tokens.size != STANDARD_TOKEN_COUNT => build_template_function_call()

		left = parser.parse(environment, tokens[LEFT])

		# If the right operand is a parenthesis token, this is a cast expression
		if tokens[RIGHT].match(TOKEN_TYPE_PARENTHESIS) {
			# Read the cast type from the parenthesis token
			abort('Link casting is not supported')
		}

		# Try to retrieve the primary context from the left token
		primary = left.try_get_type()
		right = none as Node
		token = tokens[RIGHT]

		if primary == none {
			# Since the primary context could not be retrieved, an unresolved link node must be returned
			if token.match(TOKEN_TYPE_IDENTIFIER) {
				right = UnresolvedIdentifier(token.(IdentifierToken).value, token.position)
			}
			else token.match(TOKEN_TYPE_FUNCTION) {
				right = UnresolvedFunction(token.(FunctionToken).name, token.position).set_arguments(token.(FunctionToken).parse(environment))
			}
			else {
				abort('Could not create unresolved node')
			}

			=> LinkNode(left, right, tokens[OPERATOR].position)
		}

		right = parser.parse(environment, primary, token)

		# Try to build the right node as a virtual function or lambda call
		if right.match(NODE_UNRESOLVED_FUNCTION) {
			# TODO: Support virtual calls and lambda calls
		}

		=> LinkNode(left, right, tokens[OPERATOR].position)
	}
}

Pattern ListPattern {
	constant LEFT = 0
	constant COMMA = 1
	constant RIGHT = 2

	init() {
		# Pattern: ... , ...
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[COMMA].(OperatorToken).operator == Operators.COMMA
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		left = tokens[LEFT]
		right = tokens[RIGHT]
		
		# If the left token represents a list node, add the right operand to it and return the list
		if left.match(TOKEN_TYPE_DYNAMIC) {
			node = left.(DynamicToken).node
			
			if node.match(NODE_LIST) {
				node.add(parser.parse(context, right))
				=> node
			}
		}

		=> ListNode(tokens[COMMA].position, parser.parse(context, left), parser.parse(context, right))
	}
}

Pattern SingletonPattern {
	init() {
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_NUMBER | TOKEN_TYPE_STRING)
		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> parser.parse(context, tokens[0])
	}
}

Pattern LoopPattern {
	constant KEYWORD = 0
	constant STEPS = 1
	constant BODY = 3

	constant WHILE_LOOP = 1 # Example: (i < 10)
	constant SHORT_FOR_LOOP = 2 # Example: (i < 10, i++)
	constant FOR_LOOP = 3 # (i = 0, i < 10, i++)

	init() {
		# Pattern: loop [(...)] [\n] {...}
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 1
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[KEYWORD].(KeywordToken).keyword == Keywords.LOOP and tokens[BODY].match(`{`)
	}

	private static get_steps(context: Context, state: ParserState, parenthesis: ParenthesisToken) {
		if parenthesis.tokens.size == 0 => none as Node

		steps = none as Node
		sections = parenthesis.get_sections()

		if sections.size == WHILE_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(Node())
		}
		else sections.size == SHORT_FOR_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else sections.size == FOR_LOOP {
			steps = Node()
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[2], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else {
			state.error = Status(parenthesis.position, 'Too many sections')
			=> none as Node
		}

		=> steps
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		steps_context = Context(context, NORMAL_CONTEXT)
		body_context = Context(steps_context, NORMAL_CONTEXT)

		steps_token = tokens[STEPS]
		steps = none as Node

		if steps_token.type != TOKEN_TYPE_NONE {
			steps = get_steps(steps_context, state, steps_token as ParenthesisToken)
			if steps == none => none as Node
		}

		body_token = tokens[BODY] as ParenthesisToken
		body = ScopeNode(body_context, body_token.position, body_token.end)

		parser.parse(body, body_context, body_token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		=> LoopNode(steps_context, steps, body, tokens[KEYWORD].position)
	}
}

Pattern CastPattern {
	constant OBJECT = 0
	constant CAST = 1
	constant TYPE = 2

	init() {
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_KEYWORD)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[CAST].(KeywordToken).keyword == Keywords.AS and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		type = common.read_type(context, tokens, TYPE)

		if type == none abort('Can not resolve the cast type')

		=> CastNode(object, TypeNode(type, tokens[TYPE].position), tokens[CAST].position)
	}
}

Pattern UnarySignPattern {
	constant SIGN = 0
	constant OBJECT = 1
	
	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		sign = tokens[SIGN].(OperatorToken).operator
		if sign != Operators.ADD and sign != Operators.SUBTRACT => false
		if state.start == 0 => false
		previous = state.all[state.start - 1]
		=> previous.type == TOKEN_TYPE_OPERATOR or previous.type == TOKEN_TYPE_KEYWORD
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		sign = tokens[SIGN].(OperatorToken).operator

		if object.match(NODE_NUMBER) {
			if sign == Operators.SUBTRACT => object.(NumberNode).negate()
			=> object
		}

		if sign == Operators.SUBTRACT => NegateNode(object, tokens[SIGN].position)
		=> object
	}
}

Pattern PostIncrementPattern {
	constant OBJECT = 0
	constant OPERATOR = 1

	init() {
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		operator = tokens[OPERATOR].(OperatorToken).operator
		=> operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) => IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
		=> DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
	}
}

Pattern PreIncrementPattern {
	constant OPERATOR = 0
	constant OBJECT = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		operator = tokens[OPERATOR].(OperatorToken).operator
		=> operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) => IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
		=> DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
	}
}

Pattern NotPattern {
	constant NOT = 0
	constant OBJECT = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 14
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[NOT].match(Operators.EXCLAMATION) or tokens[NOT].match(Keywords.NOT)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> NotNode(parser.parse(context, tokens[OBJECT]), tokens[NOT].position)
	}
}

Pattern AccessorPattern {
	constant OBJECT = 0
	constant ARGUMENTS = 1

	init() {
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		parenthesis = tokens[ARGUMENTS] as ParenthesisToken
		=> parenthesis.opening == `[` and not parenthesis.empty
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		arguments = parser.parse(context, tokens[ARGUMENTS])

		=> AccessorNode(object, arguments, tokens[ARGUMENTS].position)
	}
}

Pattern ImportPattern {
	constant CPP_LANGUAGE_TAG_1 = 'cpp'
	constant CPP_LANGUAGE_TAG_2 = 'c++'
	constant VIVID_LANGUAGE_TAG = 'vivid'

	constant IMPORT = 0
	constant LANGUAGE = 1
	constant FUNCTION = 2
	constant COLON = 3

	constant TYPE_START = 1

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 20
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[IMPORT].(KeywordToken).keyword != Keywords.IMPORT => false

		next = state.peek()
		
		# Pattern: import $1.$2. ... .$n
		if next != none and next.match(TOKEN_TYPE_IDENTIFIER) => common.consume_type(state)

		# Pattern: import ['$language'] $name (...) [: $type]
		# Optionally consume a language identifier
		state.consume_optional(TOKEN_TYPE_STRING)

		if not state.consume(TOKEN_TYPE_FUNCTION) => false

		next = state.peek()

		# Try to consume a return type
		if next != none and next.match(Operators.COLON) => common.consume_type(state)

		# There is no return type, so add an empty token
		state.tokens.add(Token(TOKEN_TYPE_NONE))
		=> true
	}

	# Summary: Return whether the captured tokens represent a function import instead of namespace import
	private static is_function_import(tokens: List<Token>) {
		=> not tokens[TYPE_START].match(TOKEN_TYPE_IDENTIFIER)
	}

	# Summary: Imports the function contained in the specified tokens
	private static import_function(environment: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[FUNCTION] as FunctionToken
		language = LANGUAGE_VIVID

		if tokens[LANGUAGE].match(TOKEN_TYPE_STRING) {
			language = when(tokens[LANGUAGE].(StringToken).text.to_lower()) {
				CPP_LANGUAGE_TAG_1 => LANGUAGE_CPP
				CPP_LANGUAGE_TAG_2 => LANGUAGE_CPP
				VIVID_LANGUAGE_TAG => LANGUAGE_VIVID
				else => LANGUAGE_OTHER
			}
		}

		return_type = primitives.create_unit()

		# If the colon operator is present, it means there is a return type in the tokens
		if tokens[COLON].match(Operators.COLON) {
			return_type = common.read_type(environment, tokens, COLON + 1)
			
			# Ensure the return type was read successfully
			if return_type == none {
				state.error = Status(descriptor.position, 'Can not resolve the return type')
				=> false
			}
		}

		function = Function(environment, MODIFIER_DEFAULT | MODIFIER_IMPORTED, descriptor.name, descriptor.position, none as Position)
		function.language = language

		result = descriptor.get_parameters(function)
		
		if not (result has parameters) {
			state.error = Status(descriptor.position, result.value as String)
			=> false
		}

		function.parameters = parameters

		implementation = FunctionImplementation(function, return_type, environment)
		
		# Try to set the parsed parameters
		status = implementation.set_parameters(parameters)

		if status.problematic {
			state.error = status
			=> false
		}
		
		function.implementations.add(implementation)
		implementation.implement(function.blueprint)

		environment.declare(function)
		=> true
	}

	# Summary: Imports the namespace contained in the specified tokens
	private static import_namespace(environment: Context, state: ParserState, tokens: List<Token>) {
		imported_namespace = common.read_type(environment, tokens, 1)
		
		if imported_namespace == none {
			state.error = Status('Can not resolve the import')
			=> false
		}

		environment.imports.add(imported_namespace)
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		if is_function_import(tokens) import_function(environment, state, tokens)
		else { import_namespace(environment, state, tokens) }
		=> none as Node
	}
}

Pattern ConstructorPattern {
	constant HEADER = 0

	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		priority = 21
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Constructors and destructors must be inside a type
		if not context.is_type => false

		# Ensure the function matches either a constructor or a destructor
		descriptor = tokens[HEADER] as FunctionToken
		if descriptor.name != Keywords.INIT.identifier and descriptor.name != Keywords.DEINIT.identifier => false

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Try to consume curly brackets or a heavy arrow operator
		next = state.peek()
		
		if next.match(`{`) or next.match(Operators.HEAVY_ARROW) {
			state.consume()
			=> true
		}

		=> false
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[HEADER] as FunctionToken
		type = environment as Type

		start = descriptor.position
		end = none as Position

		blueprint = none as List<Token>
		last = tokens[tokens.size - 1]

		if last.match(`{`) {
			blueprint = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			blueprint = List<Token>()
			error = common.consume_block(state, blueprint)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				=> none as Node
			}
		}

		function = none as Function
		is_constructor = descriptor.name == Keywords.INIT.identifier

		if is_constructor { function = Constructor(type, MODIFIER_DEFAULT, start, end, false) }
		else { function = Destructor(type, MODIFIER_DEFAULT, start, end, false) }

		result = descriptor.get_parameters(function)
		
		if not (result has parameters) {
			state.error = Status(descriptor.position, result.value as String)
			=> none as Node
		}

		function.parameters = parameters
		function.blueprint = blueprint

		if is_constructor type.add_constructor(function as Constructor)
		else type.add_destructor(function as Destructor)

		=> FunctionDefinitionNode(function, descriptor.position)
	}
}

Pattern ExpressionVariablePattern {
	constant ARROW = 1

	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 21
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> (context.is_type or context.is_namespace) and tokens[ARROW].match(Operators.HEAVY_ARROW)
	}

	override build(type: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[0] as IdentifierToken

		# Create function which has the name of the property but has no parameters
		function = Function(type, MODIFIER_DEFAULT, name.value, name.position, none as Position)

		# Add the heavy arrow operator token to the start of the blueprint to represent a return statement
		blueprint = List<Token>()
		blueprint.add(tokens[ARROW])

		error = common.consume_block(state, blueprint)
		if error != none {
			state.error = error
			=> none as Node
		}

		# Save the blueprint
		function.blueprint.add_range(blueprint)

		# Finally, declare the function
		type.declare(function)

		=> FunctionDefinitionNode(function, name.position)
	}
}

# CompilesPattern
# ExtensionFunctionPattern
# HasPattern
# InheritancePattern
# IsPattern
# IterationLoopPattern
# LambdaPattern
# ModifierSectionPattern
# NamespacePattern
# OverrideFunctionPattern
# RangePattern
# SectionModificationPattern
# ShortFunctionPattern
# SpecificModificationPattern
# TemplateFunctionCallPattern
# TemplateFunctionPattern
# TemplateTypePattern
# TypeInspectionPattern
# VirtualFunctionPattern
# WhenPattern