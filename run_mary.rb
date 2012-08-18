#encoding: utf-8

#
# This is for converting markdowns in command line
#
require_relative 'mary'

raw_file_name = ARGV[0]
html_file_name = raw_file_name + ".html"

if !FileTest.exist?(raw_file_name) then
	puts "File not found"
	exit
end

raw_text = File.read(raw_file_name)

converter = MaRy.new

html =  converter.markdown2html(raw_text)

html_file = File.new(html_file_name, "w")
html_file.print html
html_file.close