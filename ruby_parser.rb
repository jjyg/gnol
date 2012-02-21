class Parser
	class Token
		# token attributes
		attr_accessor :type, :value
		# boolean to tell if the token was preceded by space and/or newline
		# on newline, space is reset to false
		attr_accessor :newline, :space
		# where was the token defined ?
		attr_accessor :file, :lineno
		# token raw data
		attr_accessor :raw_str, :raw_off, :raw_pre_spc_off, :raw_end_off

		def initialize
			# file =; lineno =
		end
	end

	attr_accessor :src, :off
	def initialize
		@unreadtok = []
		parse ''
	end

	def readtok
		if tok = @unreadtok.pop; return tok; end

		# off points to the next unchecked character
		return if @off >= @src.length

		tok = Token.new

		#tok.raw_str = @src
		tok.raw_pre_spc_off = @off

		# skipspace
		while c = @src[@off]
			case c
			when ?\ , ?\t, ?\r
				@off += 1
				tok.space = true
			when ?\n
				@off += 1
				@lineno += 1
				tok.space = false
				tok.newline = true
			when ?#
				tok.space = true
				while c != ?\n
					@off += 1
					break if not c = @src[@off]
				end
			else break
			end
		end

		tok.raw_off = @off

		# TODO heredoc, DATA/__END__, __FILE__, __LINENO__, backslash-nl, %q{}
		case c
		when ?a..?z, ?A..?Z, ?_
			@off += 1
			tok.type = :identifier
			loop do
				case @src[@off]
				when ?a..?z, ?A..?Z, ?_, ?0..?9; @off += 1
				when ??, ?!; @off += 1; break
				else break
				end
			end
		when ?0..?9
			tok.value = 0
			tok.type = :integer
			if c == ?0 and (@src[@off] == ?x or @src[@off] == ?X)
				@off += 2
				loop do
					case c = @src[@off]
					when ?_
					when ?0..?9
						tok.value *= 16
						tok.value += c - ?0.ord
					when ?a..?f
						tok.value *= 16
						tok.value += c - ?a.ord + 10
					when ?A..?F
						tok.value *= 16
						tok.value += c - ?A.ord + 10
					else break
					end
					@off += 1
				end
			else
				loop do
					case c = @src[@off]
					when ?_
					when ?0..?9
						tok.value *= 10
						tok.value += c - ?0.ord
					else break
					end
					@off += 1
				end
				if c == ?. and ((?0..?9) === @src[@off+1])
					tok.type = :float
					@off += 1
					mul = 0.1
					loop do
						case c = @src[@off]
						when ?_
						when ?0..?9
							tok.value += (c - ?0.ord) * mul
							mul /= 10.0
						else break
						end
						@off += 1
					end
				end
			end
		when ?$
			@off += 1
			tok.type = :global
			case @src[@off]
			when ?a..?z, ?A..?Z, ?_
				loop do
					@off += 1
					case @src[@off]
					when ?a..?z, ?A..?Z, ?_, ?0..?9
					else break
					end
				end
			when ?=, ?+, ?-, ?/, ?%, ?^, ?!, ?*, ?>, ?<, ?&, ?|, ?,,
				?;, ?[, ?], ?{, ?}, ?~, ?., ?', ?", ?`, ??, ?#
				# XXX check list, also check multichars
				@off += 1
			else
				return	# XXX raise
			end
		when ?:
			@off += 1
			tok.type = :symbol
			tok.value = ':'
			case c = @src[@off]
			when ?'
				loop do
					@off += 1
					case c = @src[@off]
					when nil; return	# XXX raise
					when ?'
						@off += 1
						break
					when ?\\
						@off += 1
						case c = @src[@off]
						when nil; return	# XXX raise
						when ?', ?\\
						else tok.value << ?\\
						end
					end
					tok.value << c
				end
			when ?"
				@off += 1
				case readtok_dquot(tok)
				when :string
				when :string_interp; tok.type = :symbol_interp
				when :string_interp_var; tok.type = :symbol_interp_var
				else return	# XXX raise
				end
			when ?@
				@off += 1
				tok.value << c
				if @src[@off] == c
					@off += 1
					tok.value << c
				end
				loop do
					@off += 1
					case c = @src[@off]
					when ?a..?z, ?A..?Z, ?_, ?0..?9
						tok.value << c
					else break
					end
				end
			when ?a..?z, ?A..?Z, ?_
				tok.value << c
				loop do
					@off += 1
					case c = @src[@off]
					when ?a..?z, ?A..?Z, ?_, ?0..?9
						tok.value << c
					else break
					end
				end
			else
				# single ':' (eg hash delimiter)
				tok.type = :punctuation
			end
		when ?@
			@off += 1
			if (c = @src[@off]) == ?@
				tok.type = :cvar
				@off += 1
			else
				tok.type = :ivar
			end
			case @src[@off]
			when ?a..?z, ?A..?Z, ?_
				loop do
					@off += 1
					case @src[@off]
					when ?a..?z, ?A..?Z, ?_, ?0..?9
					else break
					end
				end
			else
				@off = tok.raw_off
				return
			end
		when ?=
			@off += 1
			case @src[off]
			when ?=
				@off += 1
				@off += 1 if @src[@off] == ?=
			when ?~
				@off += 1
			end
		when ?+, ?-, ?/, ?%, ?^, ?!
			@off += 1
			@off += 1 if @src[@off] == ?=
		when ?*, ?>, ?<, ?&, ?|
			@off += 1
			@off += 1 if @src[@off] == c
			@off += 1 if @src[@off] == ?=
		when ?,, ?;, ?[, ?], ?{, ?}, ?(, ?), ?~
			@off += 1
			# nothing to do
		when ?.
			@off += 1
			@off += 1 if @src[@off] == c
			@off += 1 if @src[@off] == c
		when ?'
			tok.type = :string
			tok.value = ''
			loop do
				@off += 1
				case c = @src[@off]
				when nil; return	# XXX raise
				when ?'
					@off += 1
					break
				when ?\\
					@off += 1
					case c = @src[@off]
					when nil; return	# XXX raise
					when ?', ?\\
					else tok.value << ?\\
					end
				end
				tok.value << c
			end
		when ?", ?`, ?/
			# TODO %q{}
			@off += 1
			if c == ?/
				tok.type = :regexp
			else
				tok.type = :string
			end
			tok.value = ''
			case ret = readtok_dquot(tok, c)
			when :string
			when :string_interp
				tok.type = ((tok.type == :regexp) ? :regexp_interp : ret)
			when :string_interp_var
				tok.type = ((tok.type == :regexp) ? :regexp_interp_var : ret)
			else return	# XXX raise
			end
		when ??
			@off += 1
			tok.type = :integer
			case c = @src[@off]
			when ?\\
				@off += 1
				case v = readtok_str_escape
				when Integer; tok.value = v
				else return	# XXX raise
				end
			else
				@off += 1
				tok.value = c
			end
		else
			@off = tok.raw_off
			return
		end

		tok.raw_end_off = @off
		tok.value ||= @src[tok.raw_off...@off]
		tok.type ||= :punctuation

		tok
	end

	# reads a double-quoted string
	# returns:
	#  :string if all went correctly
	#  :string_interp if stopped due to a #{}
	#  :string_interp_var if stopped due to a #@lol
	#  :err_eof reached EOF
	#  :err_escape bad escape sequence ("\xmoo")
	def readtok_dquot(tok, terminator=?")
		while c = @src[@off]
			case c
			when ?#
				case @src[@off+1]
				when ?$, ?@
					@off += 1
					return :string_interp_var
				when ?{
					@off += 2
					return :string_interp
				else
					@off += 1
					tok.value << c
				end
			when ?\\
				@off += 1
				case v = readtok_str_escape
				when Integer; tok.value << v
				else return v
				end
			else
				@off += 1
				return :string if c == terminator
				tok.value << c
			end
		end
		:err_eof
	end

	# read a string escape (\n, \x42)
	# @off points right after the \ 
	# returns:
	#  :err_escape escape sequence error (\xmoo)
	#  :err_eof EOF
	#  Integer: the value of the character (\n => 0xa, \m => ?m)
	def readtok_str_escape
		c = @src[@off]
		@off += 1
		case c
		when nil; :err_eof
		when ?t; ?\t
		when ?r; ?\r
		when ?n; ?\n
		when ?x
			v = :err_escape
			case c = @src[@off]
			when ?0..?9
				v = c - ?0.ord
				@off += 1
			when ?a..?f
				v = c - ?a.ord + 10
				@off += 1
			when ?A..?F
				v = c - ?A.ord + 10
				@off += 1
			end
			case c = @src[@off]
			when ?0..?9
				v *= 16
				v += c - ?0.ord
				@off += 1
			when ?a..?f
				v *= 16
				v += c - ?a.ord + 10
				@off += 1
			when ?A..?F
				v *= 16
				v += c - ?A.ord + 10
				@off += 1
			end
			v
		when ?0..?7
			v = c - ?0.ord
			case c = @src[@off]
			when ?0..?7
				v *= 8
				v += c - ?0.ord
				@off += 1
				case c = @src[@off]
				when ?0..?7
					v *= 8
					v += c - ?0.ord
					@off += 1
				end
			end
			v
		# TODO more escapes
		else c
		end
	end

	def unreadtok(tok)
		@unreadtok << tok
	end

	def parse_statement
		seq = []

		while tok = readtok
			case tok.value
			when 'class'
			when 'def'
			when 'if'
			when 'case'
			when 'return'
			when 'when', 'end', '}'
  				unreadtok tok
  				break
			else
  				unreadtok tok
				seq << parse_expression
			end
		end

		[:seq, seq]
	end

	def parse(str)
		@src = str
		@off = 0
		@lineno = 1
		# @filename =
		parse_statement
	end
end
