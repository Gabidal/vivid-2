BUNDLE_FILES = 'files'

SourceFile {
	fullname: String
	content: String
	index: large
	tokens: List<Token>
	root: Node
	context: Context
	
	init(fullname: String, content: String, index: large) {
		this.fullname = fullname.replace(`\\`, `/`)
		this.content = content
		this.index = index
	}

	filename() {
		i = fullname.last_index_of(`/`)
		if i < 0 { i = 0 }
		=> fullname.slice(i + 1, fullname.length)
	}
}

# Summary: Loads the files which are stored in the specified bundle
load(bundle: Bundle) {
	object = bundle.get_object(String(BUNDLE_FILENAMES))
	if object.empty => Status('Please enter input files')
	
	filenames = object.value as List<String>
	files = Array<SourceFile>(filenames.size)

	loop (i = 0, i < files.count, i++) {
		filename = filenames[i]

		bytes = io.read_file(filename)
		if bytes.empty => Status((String('Could not load file ') + filename).text)

		content = String(bytes.value.data, bytes.value.count).replace(`\r`, ` `).replace(`\t`, ` `)
		files[i] = SourceFile(filename, content, i)
	}

	bundle.put(String(BUNDLE_FILES), files as link)
	=> Status()
}