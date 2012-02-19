class Parser
	class Token
		attr_accessor :raw, :type, :newline, :space, :file, :lineno

		def initialize
			@raw = ''
			# file =; lineno =
		end
	end

	attr_accessor :src, :off
	def initialize(str)
		@src = str
		@off = 0
		# @lineno, @filestack
		@unreadtok = []
	end

	def readtok
		if tok = @unreadtok.pop; return tok; end

		# off points to the next unchecked character
		return if @off >= @src.length

		tok = Token.new

		c = @src[@off]; @off += 1
skipspace

		tok.raw << c
		case c
		when ?a..?z, ?A..?Z, ?_
			tok.type = :identifier
			loop do
				case @src[@off]
				when ?a..?z, ?A..?Z, ?_, ?0..?9; tok.raw << @src[@off]; @off += 1
				when ??, ?!; tok.raw << @src[@off]; @off += 1; break
				else break
				end
			end
		when ?0..?9
			loop do
				case @src[@off]
				when ?_
				when ?0..?9; tok.raw << @src[@off]; @off += 1
				when ?.
					break if tok.type == :float 
					case @src[@off+1]
					when ?0..?9
						tok.type = :float
						tok.raw << @src[@off]; @off += 1
					else break
					end
				else break
				end
			end
			tok.type ||= :integer
		when ?$
			tok.type = :global
			case @src[@off]
			when ?a..?z, ?A..?Z, ?_
  				tok.raw << @src[@off]; @off += 1
				loop do
					case @src[@off]
					when ?a..?z, ?_, ?A..?Z, ?0..?9
						tok.raw << @src[@off]; @off += 1
					else break
					end
				end
			when ?=, ?+, ?-, ?/, ?%, ?^, ?!, ?*, ?>, ?<, ?&, ?|, ?,,
				?;, ?[, ?], ?{, ?}, ?~, ?., ?', ?", ?`, ??, ?#
				tok.raw << @src[@off]; @off += 1
			else
				@off -= tok.raw.length
				return
			end
		when ?:
			tok.type = :symbol
			case @src[@off]
			when ?', ?"
				# TODO
mootmoot
				break
			when ?@
				tok.raw << @src[@off]; @off += 1
				if @src[@off] == ?@
					tok.raw << @src[@off]; @off += 1
				end
			when ?a..?z, ?A..?Z, ?_
			else
				tok.type = :punctuation
				break
			end

			case @src[@off]
			when ?a..?z, ?A..?Z, ?_
  				tok.raw << @src[@off]; @off += 1
				loop do
					case @src[@off]
					when ?a..?z, ?_, ?A..?Z, ?0..?9
						tok.raw << @src[@off]; @off += 1
					else break
					end
				end
			else
				@off -= tok.raw.length
				return
			end
		when ?@
			if @src[@off] == ?@
				tok.type = :cvar
				tok.raw << @src[@off]; @off += 1
			else
				tok.type = :ivar
			end
			case @src[@off]
			when ?a..?z, ?A..?Z, ?_
  				tok.raw << @src[@off]; @off += 1
				loop do
					case @src[@off]
					when ?a..?z, ?_, ?A..?Z, ?0..?9
						tok.raw << @src[@off]; @off += 1
					else break
					end
				end
			else
				@off -= tok.raw.length
				return
			end
		when ?=
			case @src[off]
			when ?=
				tok.raw << @src[@off]; @off += 1
				if @src[@off] == ?=
					tok.raw << @src[@off]; @off += 1
				end
			when ?~
				tok.raw << @src[@off]; @off += 1
			end
		when ?+, ?-, ?/, ?%, ?^, ?!
			if @src[@off] == ?=
				tok.raw << @src[@off]; @off += 1
			end
		when ?*, ?>, ?<, ?&, ?|
			if @src[@off] == c
				tok.raw << @src[@off]; @off += 1
			end
			if @src[@off] == ?=
				tok.raw << @src[@off]; @off += 1
			end
		when ?,, ?;, ?[, ?], ?{, ?}, ?~
		when ?.
			if @src[@off] == c
				tok.raw << @src[@off]; @off += 1
			end
			if @src[@off] == c
				tok.raw << @src[@off]; @off += 1
			end
		when ?', ?", ?`
			gettok_string(c)
		when ??
			tok.type = :integer
			if @src[@off] == ?\\
				tok.raw << @src[@off]; @off += 1
				tok.raw << @src[@off]; @off += 1
			else
				tok.raw << @src[@off]; @off += 1
			end
		else
			@off -= tok.raw.length
			return
		end

		tok.type ||= :punctuation
skipspace

		tok
	end

	def unreadtok(tok)
		@unreadtok << tok
	end

	def parse_statement
		seq = []

		while tok = readtok
			case tok.raw
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
end
