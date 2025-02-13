export loops(start: large, count: large) {
	result = start

	i = 0
	j = 0

	loop (i, i < count, ++i) {
		result += j
		j += 3
	}

	=> result
}

export forever_loop() {
	result = 0

	loop {
		++result
	}

	=> result
}

export conditional_loop(i: large) {
	loop (i < 10) {
		++i
	}

	=> i
}

export conditional_action_loop(i: large) {
	loop (i < 1000, i *= 2) {}
	=> i
}

export normal_for_loop(start: large, count: large) {
	result = start

	loop (i = 0, i < count, ++i) {
		result += i
	}

	=> result
}

export normal_for_loop_with_stop(start: large, count: large) {
	result = start

	loop (i = 0, i <= count, ++i) {
		
		if (i > 100) {
			result = -1
			stop
		}

		result += i
	}

	=> result
}

export normal_for_loop_with_continue(start: large, count: large) {
	result = start

	loop (i = 0, i < count, ++i) {
		
		if (i % 2 == 0) {
			result += 1
			continue
		}

		result += i
	}

	=> result
}

export nested_for_loops(memory: link, width: large) {
	w = 0

	loop (z = 0, z < width, ++z) {
		loop (y = 0, y < width, ++y) {
			if (y == 0) {
				++w
			}

			loop (x = 0, x < width, ++x) {
				if x % 2 == 0 and y % 2 == 0 and z % 2 == 0 {
					memory[z * width * width + y * width + x] = 100
				}
				else {
					memory[z * width * width + y * width + x] = 0
				}

				if (x == 0) {
					++w
				}
			}
		}

		if (z == 0) {
			++w
		}
	}

	=> w
}

init() {
	are_equal(100, loops(70, 5))

	are_equal(10, conditional_loop(3))
	are_equal(1344, conditional_action_loop(42))

	are_equal(3169, normal_for_loop(3141, 8))

	are_equal(220, normal_for_loop_with_stop(10, 20))
	are_equal(3, normal_for_loop_with_stop(-3, 3))
	are_equal(10, normal_for_loop_with_stop(10, -1))
	are_equal(-1, normal_for_loop_with_stop(0, 999))

	are_equal(62, normal_for_loop_with_continue(42, 8))
	are_equal(42, normal_for_loop_with_continue(42, -1))

	expected = allocate(27)
	expected[0] = 100
	expected[1] = 0
	expected[2] = 100
	expected[3] = 0
	expected[4] = 0
	expected[5] = 0
	expected[6] = 100
	expected[7] = 0
	expected[8] = 100
	expected[9] = 0
	expected[10] = 0
	expected[11] = 0
	expected[12] = 0
	expected[13] = 0
	expected[14] = 0
	expected[15] = 0
	expected[16] = 0
	expected[17] = 0
	expected[18] = 100
	expected[19] = 0
	expected[20] = 100
	expected[21] = 0
	expected[22] = 0
	expected[23] = 0
	expected[24] = 100
	expected[25] = 0
	expected[26] = 100

	actual = allocate(27)
	result = nested_for_loops(actual, 3)

	are_equal(expected, actual, 0, 27)
	are_equal(13, result)
	=> 1
}