#encoding: utf-8

#
# MaRy.rb is a Markdown-to-HTML interpreter implemented in Ruby.
# MaRy is based on Markdown.pl by John Gruber.
# 
# MaRy:
# Copyright (c) 2012 LiWY
# <areosome@gmail.com>
#
# Original Markdown.pl:
# Copyright (c) 2004 John Gruber
# <http://daringfireball.net/projects/markdown/>
#
#
# version 0.1

require 'digest/md5'
require 'strscan'


class MaRy
	
	def initialize
		# Initialization, setting up variables
		@tab_width = 4
		@empty_suffix = "/>"
		@list_level = 0
		@nested_brackets = //
		@nested_brackets = /(?>[^\[\]]+
					 |
					 \[
						(?:{#{@nested_brackets}})
					 \])*
				   /x
		@escape_table = {}
		@html_blocks = {}
		@titles = {}	
		@urls = {}

		"\\`*_{}[]()#+-.!>".split('').each do |c|
			@escape_table[c] = Digest::MD5.hexdigest(c)
		end
	end


	def markdown2html(text)
		#
		# Process the input text and interpret it to HTML 
		# text -- markdown string
		# returns HTML as output
		#

		# Some preprocessing on the raw input
		regexp_BOM = /^\xEF\xBB\xBF|\x1A/
		regexp_blankline = /^[ \t]+$/
		text.gsub!(regexp_BOM, '')			#remove BOM
		text.gsub!(/\r\n/, "\n")			#DOS to Unix
		text.gsub!(/\r/, "\n")				#Mac to Unix
		text.gsub!(regexp_blankline, '')	#substitute lines with only tabs and spaces
		text = text.concat("\n\n")

		text = detab(text);
		text.gsub!(/^[ \t]+$/, '')

		text = hash_HTML_blocks(text)
		text = strip_link_def(text)
		text = run_block_gamut(text)
		text = unescape_special_chars(text)

		# Return the equivalent HTML as result of conversion
		return text + "\n"
	end


	def detab(text)
		return text.gsub(/\t/, " " * @tab_width)	
	end


	def hash_HTML_blocks(text)
		less_than_tab = @tab_width - 1
		regexp_tags_a = /p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del/
		regexp_tags_b = /p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math/
		
		text.gsub!(/
						(							# save in $1
							^
							<(#{regexp_tags_a})		# start tag = $2
							\b						# word break
							(.*\n)*?				
							<\/\2>
							[\t]*
							(?=\n+|\Z)
						)
				   /x) do
			key = Digest::MD5.hexdigest($1)
			@html_blocks[key] = $1
			"\n\n#{key}\n\n"
		end
		
		text.gsub!(/
						(
							^
							<(#{regexp_tags_b})
							\b
							(.*\n)*?
							.*<\/\2>
							[\t]*
							(?=\n+|\Z)
						)
					/x) do
			key = Digest::MD5.hexdigest($1)
			@html_blocks[key] = $1;
			"\n\n#{key}\n\n"
		end
		
		text.gsub!(/
					 	(?:
						 	(?<=\n\n)
							|
							\A\n?
						)
						(
							[ ]{0,#{less_than_tab}}
							<(hr)
							\b
							([^<>])*?
							\/?>
							[\t]*
							(?=\n{2,}|\Z)
						)
					/x) do
			key = Digest::MD5.hexdigest($1)
			@html_blocks[key] = $1
			"\n\n#{key}\n\n"
		end

		text.gsub!(/
					 	(?:
						 	(?<=\n\n)
							|
							\A\n?
						)
						(
							[ ]{0,#{less_than_tab}}
							(?:						
							 	<!
								(--.*?--\s*)+
								>
							)
							[\t]*
							(?=\n{2,}|\Z)
						)
					/x) do
			key = Digest::MD5.hexdigest($1)
			@html_blocks[key] = $1
			"\n\n#{key}\n\n"
		end

		return text
	end


	def strip_link_def(text)
		less_than_tab = @tab_width - 1

		#Link defs are in the form: ^[id]: url "optional title"
		text.gsub!(/^[ ]{0,#{less_than_tab}}\[([^\]]+)\]:
						   [ \t]*
						   \n?
						   [ \t]*
						  <?(\S+?)>?
						   [ \t]*
						   \n?
						   [ \t]*
						  (?:
						   	(?<=\s)
						    ["'(]
							(.+?)
							["')]
							[ \t]*
						  )?
						  (?:\n+|$)
						/x) do
			@urls[$1.downcase] = encode_amps_and_angles($2);
			if (!$3.nil?)
				@titles[$1.downcase] = $3.gsub(/"/, "&quot;")
			end
			''
		end

		return text
	end


	def run_block_gamut(text)
		#
		# These are all the transformations that form block-level
		# tags like paragraphs, headers, and list items.
		#
		
		text = do_headers(text)

		text.gsub!(/^[ ]{0,2}([ ]?\*[ ]?){3,}[\t]*$/x, "\n<hr#{@empty_suffix}\n")
		text.gsub!(/^[ ]{0,2}([ ]? -[ ]?){3,}[\t]*$/x, "\n<hr#{@empty_suffix}\n")
		text.gsub!(/^[ ]{0,2}([ ]? _[ ]?){3,}[\t]*$/x, "\n<hr#{@empty_suffix}\n")

		text = do_lists(text)
		text = do_codeblocks(text)
		text = do_block_quotes(text)

		text = hash_HTML_blocks(text)

		text = form_paragraphs(text)

		return text
	end


	def run_span_gamut(text)
		#
		# These are all the transformations that occur *within* block-level
		# tags like paragraphs, headers, and list items.
		#
		
		text = do_code_spans(text)

		text = escape_special_chars(text)

		text = do_images(text)
		text = do_anchors(text)

		text = do_auto_links(text)

		text = encode_amps_and_angles(text)

		text = do_italics_and_bold(text)

		#hard breaks
		text.gsub!(/[ ]{2,}\n/, " <br #{@empty_suffix}\n")

		return text
	end


	def do_headers(text)
		#Setext-style
		text.gsub!(/^(.+)[\t]*\n=+[\t]*\n+/) {"<h1>" + run_span_gamut($1) + "</h1>\n\n"}
		text.gsub!(/^(.+)[\t]*\n-+[\t]*\n+/) {"<h2>" + run_span_gamut($1) + "</h2>\n\n"}

		#atx-style
		text.gsub!(/^(\#{1,6})
				    [\t]*
					(.+?)
					[\t]*
					\#*
					\n+
				   /x) do
			h_level = $1.length
			"<h#{h_level}>" + run_span_gamut($2) + "</h#{h_level}>\n\n"
		end

		return text
	end


	def do_lists(text)
		less_than_tab = @tab_width - 1

		marker_ul = /[*+-]/
		marker_ol = /\d+[.]/
		marker_any = /(?:#{marker_ul}|#{marker_ol})/

		entire_list = /(								# save entire list in $1
						(								# $2
							[ ]{0,#{less_than_tab}}
							(#{marker_any})				# first marker
							[ \t]+?
						)
						(?:.+?)
						(
							\z
							|
							\n{2,}
							(?=\S)
							(?!
								[ \t]*
								#{marker_any}
								[ \t]+
							)
						)
				   )/mx

		if (@list_level > 0)
			text.gsub!(/^#{entire_list}/mx) do 
				list = $1
				list_type = ($3 =~ /#{marker_ul}/).nil? ? "ol" : "ul"
				#double returns -> triple returns
				list.gsub!(/\n{2,}/, "\n\n\n")
				result = process_list_items(list, marker_any)
				result = "<#{list_type}>\n" + result + "</#{list_type}>\n"
				result
			end
		else

			text.gsub!(/(?:(?<=\n\n)|\A\n?)#{entire_list}/mx) do
				list = $1
				list_type = ($3 =~ /#{marker_ul}/).nil? ? "ol" : "ul"
				#double returns -> triple returns
				list.gsub!(/\n{2,}/, "\n\n\n")
				result = process_list_items(list, marker_any)
				result = "<#{list_type}>\n" + result + "</#{list_type}>\n"
				result
			end
		end

		return text
	end


	def process_list_items(list, marker)
		#
		#	Process the contents of a single ordered or unordered list, splitting it
		#	into individual list items.
		#
		
		@list_level += 1
		list.gsub!(/\n{2,}\z/, "\n")
		list.gsub!(/(\n)?									#leading_line=$1
				   	(^[ \t]*)								#leading_space=$2
					(#{marker}) [ \t]+						#marker=$3
					((?:.+?)								#item=$4
					(\n{1,2}))
					(?= \n* (\z | \2 (#{marker}) [ \t]+))
				  /mx) do 
			item = $4
			leading_line = $1
			leading_space = $2

			if(leading_line || (item =~ /\n{2,}/)) 
				item = run_block_gamut(outdent(item))
			else
				item = do_lists(outdent(item))
				item.chomp!
				item = run_span_gamut(item)
			end

			"<li>" + item + "</li>\n"
		end

		@list_level -= 1
		return list
	end


	def do_codeblocks(text)
		text.gsub!(/
				   	(?:\n\n|\A)
					(
						(?:
						 	(?:[ ]{#{@tab_width}} | \t)
							.*\n+
						)+
					)
					((?=^[ ]{0,#{@tab_width}}\S)|\Z)
				  /mx) do 
			codeblock = $1
			codeblock = encode_code(outdent(codeblock))
			codeblock = detab(codeblock)
			codeblock.gsub!(/\A\n+/, '')
			codeblock.gsub!(/\s+\z/, '')

			"\n\n<pre><code>" + codeblock + "\n</code></pre>\n\n"
		end

		return text
	end

	
	def do_code_spans(text)
		#Backtick ` is used to mark <code></code> spans

		text.gsub!(/(`+)(.+?)\1(?!`)/) do 
			c = $2
			c.gsub!(/^[ \t]*/, '')
			c.gsub!(/[ \t]*$/, '')
			c = encode_code(c)

			"<code>" + c +"</code>"
		end

		return text
	end


	def do_block_quotes(text)
		text.gsub!(/(
						(
							^[ \t]*>[ \t]?
							.+\n
							(.+\n)*
							\n*
						)+
					)
				   /x) do 
			quote = $1
			quote.gsub!(/^[ \t]*>[ \t]?/, '')
			quote.gsub!(/^[ \t]+$/, '')
			quote = run_block_gamut(quote)

			quote.gsub!(/^/, "  ")
			#fix problems caused by these spaces
			quote.gsub!(/(\s*<pre>.+?<\/pre>)/) do
				pre = $1
				pre.gsub!(/^  /, '')
				pre
			end

			"<blockquote>\n" + quote + "\n</blockquote>\n\n"
		end

		return text
	end

	
	def do_images(text)
		text.gsub!(/(!\[(.*?)\]
					 [ ]?
					 (?:\n[ ]*)?
					 
					 \[
					 (.*?)
					 \]
					)
				   /x) do 
			whole_match = $1
	 		alt_text = $2
			link_id = $3.downcase
			
			if(link_id.empty?)
				link_id = alt_text.downcase
			end

			alt_text.gsub!(/"/, "&quot;")
			if(@urls.include?(link_id))
				url = @urls[link_id]
				url.gsub!(/\*/, @escape_table['*'])
				url.gsub!(/_/, @escape_table['_'])

				result = "<img src=\"#{url}\" alt=\"#{alt_text}\""
				if(@titles.include?(link_id))
				   	title = @titles[link_id]
				   	title.gsub!(/\*/, @escape_table['*'])
					title.gsub!(/_/, @escape_table['_'])
					
					result = result + " title=\"#{title}\""
				end
				result = result + @empty_suffix
			else
				#if no such link_id, leave as it is
				result = whole_match
			end
			
			result
		end	
			
		#the following part handles inline images '[alt text](url "optional title")
		text.gsub!(/(!\[(.*?)\]
				 	\(
					   [ \t]*
			   		   <?(\S+?)>?
					   [ \t]*
					   (
						(['"])		#quote char = $5
			 			(.*?)
						\5
						[ \t]*
					   )?
		   			\)
		 			)
				   /x) do
			whole_match = $1
			alt_text = $2
			url = $3
			title = ''
			
			if(!$6.nil?)
				title = $6
			end

			alt_text.gsub!(/"/, "&quot;")
			title.gsub!(/"/, "&quot;")
			url.gsub!(/\*/, @escape_table['*'])
			url.gsub!(/_/, @escape_table['_'])
			result = "<img src=\"#{url}\" alt=\"#{alt_text}\""
			
			title.gsub!(/\*/, @escape_table['*'])
			title.gsub!(/_/, @escape_table['_'])
			result = result + " title=\"#{title}\""

			result = result + @empty_suffix

			result 
		end

		return text
	end
	
	
	def do_anchors(text)
		#reference-style first [link text] [id]
		text.gsub!(/(
					 \[
						(#{@nested_brackets})  #link text = $2
					 \]
					 [ ]?
					 (?:\n[ ]*)?
					 \[
						(.*?)  #id = $3
					 \]
					)
				   /x) do 
			whole_match = $1
			link_text = $2
			link_id = $3.downcase
			
			result = ''

			if(link_id.empty?)
				link_id = link_text.downcase
			end

			if(@urls.include? link_id)
				url = @urls[link_id]
				url.gsub!(/\*/, @escape_table['*'])
				url.gsub!(/_/, @escape_table['_'])
				result = "<a href=\"#{url}\""

				if(@titles.include? link_id)
					title = @titles[link_id]
					title.gsub!(/\*/, @escape_table['*'])
					title.gsub!(/_/, @escape_table['_'])
					result = result + " title=\"#{title}\""
				end
				result = result + ">#{link_text}</a>"
			else 
				result = whole_match
			end
			
			result
		end

		#inline_style links: [link text](url "optional title")
		text.gsub!(/(
					 \[
						(#{@nested_brackets})	#link text = $2
					 \]
					 \(							#literal paren
						[ \t]*
						<?(.*?)>?				#href = $3
						[ \t]*
						(						#$4
							(['"])				#quote char = $5
							(.*?)				#title = $6
							\5
						)?
					 \)
					)
				   /x) do
			whole_match = $1
			link_text = $2
			url = $3
			title = $6
			result = ''

			url.gsub!(/\*/, @escape_table['*'])
			url.gsub!(/_/, @escape_table['_'])
			result = "<a href=\"#{url}\""

			if(!title.nil?)
				title.gsub!(/"/, "&quot;")
				title.gsub!(/\*/, @escape_table['*'])
				title.gsub!(/_/, @escape_table['_'])
				result = result + " title=\"#{title}\""
			end

			result = result + ">#{link_text}</a>"
			result
		end

		return text
	end


	def do_auto_links(text)
		text.gsub!(/<((https?|ftp):[^'">\s]+)>/) {"<a href=\"#{$1}\">#{$1}</a>"}

		text.gsub!(/<
				   	(?:mailto:)?
					(
						[-.\w]+
						\@
						[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
					)
					>
				   /xi) do
			 encode_email_address(unescape_special_chars($1))
		end

		return text
	end



	def encode_email_address(text)
		#
		#	Input: an email address, e.g. "foo@example.com"
		#
		#	Note: In the original Markdown.pl, this encode the email address
		# 		into decimal or hex entities. I skipped it to simplify my work (lazy, I know)
		# 		In future versions I may add it back in.
		#
		
		addr = "<a href=\"mailto:#{text}\">#{text}</a>"

		return addr
	end


	def do_italics_and_bold(text)
		#<strong> must go first
		
		text.gsub!(/(\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1/x) do 
			"<strong>" + $2 +"</strong>"
		end

		text.gsub!(/(\*|_) (?=\S) (.+?) (?<=\S) \1/x) do
			"<em>" + $2 + "</em>"
		end

		return text
	end


	def form_paragraphs(text)
		text.gsub!(/\A\n+/, '')
		text.gsub!(/\n+\z/, '')

		par = text.split(/\n{2,}/)
		
		#Wrap <p> tags
		par.collect! do |p|
			if(!@html_blocks.include?(p))
				p = run_span_gamut(p)
				p.sub!(/^([ \t]*)/, "<p>")	#only replace the leading spaces/tabs
				p = p + "</p>"
			else
				p
			end
		end

		#Unhashify HTML blocks
		par.collect! do |p|
			if(@html_blocks.include?(p))
				p = @html_blocks[p]
			else
				p
			end
		end

		text = par.join("\n\n")
		return text
	end


	def tokenize_HTML(text)
		#
		#   Parameter:  String containing HTML markup.
		#   Returns:    Reference to an array of the tokens comprising the input
		#               string. Each token is either a tag (possibly with nested,
		#               tags contained therein, such as <a href="<MTFoo>">, or a
		#               run of text between tags. Each element of the array is a
		#               two-element array; the first is either 'tag' or 'text';
		#               the second is the actual value.
		#
		# Note: the original _TokenizeHTML in Markdown.pl 
		#       is derived from the _tokenize() subroutine from Brad Choate's MTRegex plugin.
		#       <http://www.bradchoate.com/past/mtregex.php>
		# 
		# This is a re-written version in Ruby
		#
		
		pos = 0
		len = text.length
		tokens = []	

		depth = 6
		nested_tags_array = []
		for i in (1..depth) 
			nested_tags_array.push('(?:<[a-z/!$](?:[^<>]' * i + ')*>)' * i)
		end
		nested_tags = nested_tags_array.join('|')

		regexp_nt = /(?: <! ( -- .*? -- \s* )+ > ) | 	#comment
				 	(?: <\? .*? \?> ) |				#processing instruction
				 	#{nested_tags}/xi
		
		ss = StringScanner.new(text)
		ss.reset

		while(ss.scan_until(/(#{regexp_nt})/))
			whole_tag = ss.matched
			sec_start = ss.pos
			tag_start = sec_start - whole_tag.length
			if(pos < tag_start)
				tokens.push(['text', text[pos, tag_start - pos]])
			end
			tokens.push(['tag', whole_tag])
			pos = ss.pos
		end

		tokens.push(['text', text[pos, len - pos]]) if pos < len

		return tokens
	end


	def outdent(text)
	#
	# Remove one level of line-leading tabs or spaces
	#
		text.gsub!(/^(\t|[ ]{1,#{@tab_width}})/, '')
		return text
	end


	def encode_code(text)
		text.gsub!(/&/, '&amp;')
		# Here I skipped the part concerning encoding &s for blosxom,
		# which is part of the orginal markdown.pl

		text.gsub!(/</, '&lt;')
		text.gsub!(/>/, '&gt;')
		
		text.gsub!(/\\|\*|_|\{|\}|\[|\]/) do |match|
			@escape_table[match]	
		end

		return text
	end
	
				  
	def encode_amps_and_angles(text)
		text.gsub!(/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/, '&amp;')
		text.gsub!(/<(?![a-zA-Z\/?\$!])/, '&lt;')
		return text
	end


	def encode_backslash_escapes(text)
		text.gsub!(/\\\\/, @escape_table['\\'])
		text.gsub!(/\\`/, @escape_table['`'])
		text.gsub!(/\\\*/, @escape_table['*'])
		text.gsub!(/\\_/, @escape_table['_'])
		text.gsub!(/\\\{/, @escape_table['{'])
		text.gsub!(/\\\}/, @escape_table['}'])
		text.gsub!(/\\\[/, @escape_table['['])
		text.gsub!(/\\\]/, @escape_table[']'])
		text.gsub!(/\\\(/, @escape_table['('])
		text.gsub!(/\\\)/, @escape_table[')'])
		text.gsub!(/\\>/, @escape_table['>'])
		text.gsub!(/\\\#/, @escape_table['#'])
		text.gsub!(/\\\+/, @escape_table['+'])
		text.gsub!(/\\\-/, @escape_table['-'])
		text.gsub!(/\\\./, @escape_table['.'])
		text.gsub!(/\\!/, @escape_table['!'])

		return text
	end


	def escape_special_chars(text)
		tokens ||= tokenize_HTML(text)
		text = ''

		tokens.collect do |token|  
			if(token[0].eql? "tag")
				token[1].gsub!(/\*/, @escape_table['*'])
				token[1].gsub!(/_/, @escape_table['*'])

				text += token[1]
			else
				t = token[1]
				t = encode_backslash_escapes(t)
				
				text += t
			end
		end	

		return text
	end


	def unescape_special_chars(text)
		@escape_table.each {|key, char| text.gsub!(/#{char}/, key)}
		return text
	end


end


=begin

 DESCRIPTION
------------

MaRy -- Markdown in Ruby

This is a Ruby translation of the original Markdown.pl by John Gruber

Markdown is a text-to-HTML filter; it translates an easy-to-read /
easy-to-write structured text format into HTML. Markdown's text format
is most similar to that of plain text email, and supports features such
as headers, *emphasis*, code blocks, blockquotes, and links.

Markdown's syntax is designed not as a generic markup language, but
specifically to serve as a front-end to (X)HTML. You can use span-level
HTML tags anywhere in a Markdown document, and you can use block level
HTML tags (like <div> and <table> as well).

For more information about Markdown's syntax, see:

<http://daringfireball.net/projects/markdown/>

 COPYRIGHT AND LICENSE
----------------------

MaRy
Copyright (c) 2012 LiWY
<areosome@gmail.com>
All rights reserved.

Copyright (c) 2003-2004 John Gruber   
<http://daringfireball.net/>   
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name "Markdown" nor the names of its contributors may
  be used to endorse or promote products derived from this software
  without specific prior written permission.

This software is provided by the copyright holders and contributors "as
is" and any express or implied warranties, including, but not limited
to, the implied warranties of merchantability and fitness for a
particular purpose are disclaimed. In no event shall the copyright owner
or contributors be liable for any direct, indirect, incidental, special,
exemplary, or consequential damages (including, but not limited to,
procurement of substitute goods or services; loss of use, data, or
profits; or business interruption) however caused and on any theory of
liability, whether in contract, strict liability, or tort (including
negligence or otherwise) arising in any way out of the use of this
software, even if advised of the possibility of such damage.

=end