CURRENCY_EUROS = 0
CURRENCY_DOLLARS = 1

Pair<A, B> {
	first: A
	second: B

	init(a: A, b: B) {
		first = a
		second = b
	}
}

Bundle<A, B> {
	first: Pair<A, B>
	second: Pair<A, B>
	third: Pair<A, B>

	get(i: large) {
		if i == 0 {
			=> first
		}
		else i == 1 {
			=> second
		}
		else i == 2 {
			=> third
		}
		else {
			=> none as Pair<A, B>
		}
	}

	set(i: large, value: Pair<A, B>) {
		if i == 0 {
			first = value
		}
		else i == 1 {
			second = value
		}
		else i == 2 {
			third = value
		}
	}
}

length_of(name: link) {

}

Product {
	name: link

	get_name_length() {
		length = 0
		loop (name[length] != 0, length++) {}
		=> length
	}

	enchant() {
		length = get_name_length()
		buffer = allocate(length + 2)
		buffer[0] = `i`
		buffer[length + 1] = 0

		offset_copy(name, length, buffer, 1)

		name = buffer
	}

	is_enchanted() {
		if name[0] == 105 {
			=> true
		}

		=> false
	}
}

Price {
	value: large
	currency: tiny

	convert(c: tiny) {
		if currency == c {
			=> value
		}

		if c == CURRENCY_EUROS {
			=> value * 0.8
		}
		else {
			=> value * 1.25
		}
	}
}

export create_bundle() {
	=> Bundle<Product, Price>()
}

export set_product(bundle: Bundle<Product, Price>, i: large, name: link, value: large, currency: tiny) {
	product = Product()
	product.name = name

	price = Price()
	price.value = value
	price.currency = currency

	bundle[i] = Pair<Product, Price>(product, price)
}

export get_product_name(bundle: Bundle<Product, Price>, i: large) {
	=> bundle[i].first.name
}

export enchant_product(bundle: Bundle<Product, Price>, i: large) {
	bundle[i].first.enchant()
}

export is_product_enchanted(bundle: Bundle<Product, Price>, i: large) {
	=> bundle[i].first.is_enchanted()
}

export get_product_price(bundle: Bundle<Product, Price>, i: large, currency: tiny) {
	=> bundle[i].second.convert(currency)
}

init() {
	bundle = create_bundle()

	set_product(bundle, 0, 'Car', 700000, 0)
	set_product(bundle, 2, 'Lawnmower', 40000, 1)
	set_product(bundle, 1, 'Banana', 100, 1)

	are_equal(get_product_name(bundle, 0), 'Car', 0, 3)
	are_equal(get_product_name(bundle, 1), 'Banana', 0, 6)
	are_equal(get_product_name(bundle, 2), 'Lawnmower', 0, 9)

	enchant_product(bundle, 0)
	enchant_product(bundle, 1)

	are_equal(true, is_product_enchanted(bundle, 0))
	are_equal(true, is_product_enchanted(bundle, 1))
	are_equal(false, is_product_enchanted(bundle, 2))

	are_equal(get_product_name(bundle, 0), 'iCar', 0, 4)
	are_equal(get_product_name(bundle, 1), 'iBanana', 0, 7)

	are_equal(700000.0, get_product_price(bundle, 0, 0))
	are_equal(80.0, get_product_price(bundle, 1, 0))
	are_equal(32000.0, get_product_price(bundle, 2, 0))

	are_equal(875000.0, get_product_price(bundle, 0, 1))
	are_equal(100.0, get_product_price(bundle, 1, 1))
	are_equal(40000.0, get_product_price(bundle, 2, 1))
	=> 1
}