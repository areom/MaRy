MaRy
======

version 0.1 - Sat 18 Aug 2012

What is MaRy?
------------
MaRy is a markdown-to-HTML conversion tool implemented in Ruby, 
based on the original Markdown v1.0.1 by by John Gruber   
<http://daringfireball.net/>

Full documentation of Markdown's syntax and configuration options is
available on the web: <http://daringfireball.net/projects/markdown/>.

How to use MaRy
--------------
 - For Ruby programmers:
   MaRy is mainly designed for Ruby programmers to interpret text organized in markdown grammar.
   All you need to do is require the mary.rb, and use the markdown2html function in class MaRy,
   the markdown text being the parameter. The function will return the equivalent HTML.

   For example:
   The variable `raw_text` is a string containing text in markdown.
   Add the following code in your ruby program.


	`require_relative 'mary'`  
	`converter = MaRy.new`  
	`html = converter.markdown2html(raw_text)`


   The variable `html` will be the conversion result.

 - For command line usage:
   You can also use MaRy as a convenient tool to translate your markdown articles or notes into 
   corresponding HTML files.

   All you need to do is:  
  1. Make sure you have ruby installed on your machine  
  2. Now you can type ` ruby run_mary.rb name_of_your_markdown_file ` in your terminal and get the html file you
	     want.


Copyright and License
---------------------

MaRy
Copyright (c) 2012 LiWY   
<areosome@gmail.com>
All rights reserved.

Based on Markdown
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
