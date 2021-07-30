namespace analysis

analyze(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_PARSE)) as Optional<Parse> has parse) => Status('Nothing to analyze')

	context = parse.context
	implementations = common.get_all_function_implementations(context)
	#resolver.debug_print(context)

	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]
		if implementation.metadata.is_imported continue

		reconstruction.start(implementation, implementation.node)
		reconstruction.end(implementation.node)
	}

	#resolver.debug_print(context)
}

# Summary: Finds the branch which contains the specified node
get_branch(node: Node) {
	=> node.find_parent(NODE_LOOP | NODE_IF | NODE_ELSE_IF | NODE_ELSE)
}

# Summary: If the specified node represents a conditional branch, this function appends the other branches to the specified denylist
deny_other_branches(denylist: List<Node>, node: Node) {
	if node.instance == NODE_IF {
		loop branch in node.(IfNode).get_branches() { if branch != node denylist.add(branch) }
	}
	else node.instance == NODE_ELSE_IF {
		loop branch in node.(ElseIfNode).get_root().get_branches() { if branch != node denylist.add(branch) }
	}
	else node.instance == NODE_ELSE {
		loop branch in node.(ElseNode).get_root().get_branches() { if branch != node denylist.add(branch) }
	}
}

# Summary: Returns whether the specified perspective is inside the condition of the specified branch
is_inside_branch_condition(perspective: Node, branch: Node) {
	if branch.instance == NODE_IF {
		=> perspective == branch.(IfNode).condition_container or perspective.is_under(branch.(IfNode).condition_container)
	}
	else branch.instance == NODE_ELSE_IF {
		=> perspective == branch.(ElseIfNode).condition_container or perspective.is_under(branch.(ElseIfNode).condition_container)
	}
	else branch.instance == NODE_ELSE {
		=> perspective == branch.(LoopNode).condition_container or perspective.is_under(branch.(LoopNode).condition_container) 
	}

	=> false
}

# Summary: Returns nodes whose contents should be taken into account if execution were to start from the specified perspective
get_denylist(perspective: Node) {
	denylist = List<Node>()
	branch = perspective

	loop {
		branch = get_branch(branch)
		if branch == none stop

		# If the perspective is inside the condition of the branch, it can still enter the other branches
		if is_inside_branch_condition(perspective, branch) {
			continue
		}

		deny_other_branches(denylist, branch)
	}

	=> denylist
}

# Summary:
# Returns whether the specified variable will be used in the future starting from the specified node perspective
# NOTE: Usually the perspective node is a branch but it is not counted as one.
# This behavior is required for determining active variables when there is an if-statement followed by an else-if-statement and both of the conditions use same variables.
is_used_later(variable: Variable, perspective: Node, self: bool) {
	# Get a denylist which describes which sections of the node tree have not been executed in the past or will not be executed in the future
	denylist = get_denylist(perspective)

	# If the it is allowed to count the perspective as a branch as well, append the other branches to the denylist
	if self deny_other_branches(denylist, perspective)

	# If any of the references is placed after the specified perspective, the variable is needed
	loop usage in variable.usages {
		# Ensure the variable is used outside the excluded node trees
		skip = false
		
		loop root in denylist {
			if not usage.is_under(root) continue
			skip = true
			stop
		}

		if skip continue

		# If the variable is used after the perspective, return true
		if usage.is_after(perspective) => true
	}

	# No usage of the variable could be found after the perspective, but return true, if the perspective is inside a loop, since past variable usages might be executed again
	=> perspective.find_parent(NODE_LOOP) != none
}

is_used_later(variable: Variable, node: Node) {
	=> is_used_later(variable, node, false)
}