#!/usr/bin/env ruby
#
# Copyright (c) 2012 Prachi Gauriar.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require 'stringio'

##
# The Tabular module provides a mechanism for outputting tabular data as a string. It contains two classes: Table, which
# represents a table of data, and Column, which represents columns of data within a table. The Column class is fairly
# important, in that it encapsulates how to convert a column's data into a string, how to compare the data within a column,
# and how to format the column. The Table class uses Column instances to control its display.
module Tabular
  ##
  # Instances of Table represent tables of data. The primary purpose of the Table class is to make it easy to output its
  # data to a string in an easy-to-read manner.
  class Table
    ##
    # An array of Column objects that represent the columns in the table.
    attr_accessor :columns

    ##
    # An array of arrays. Each element of +data+ represents a row in the table. It is assumed that each element contains
    # the +columns.length+ elements, though nothing explicitly checks that.
    attr_accessor :data


    ##
    # Initializes a new Table instance with the specified columns.
    # +columns+::  A list of Column instances representing the columns in the new table.
    def initialize(*columns)
      @columns = columns
    end


    ##
    # Outputs a formatted version of the receiver. A side-effect of this method is that the width of each column in +columns+
    # will be large enough to fit its largest row value.
    def to_s
      stringio = StringIO.new

      # Set the column widths
      if @data
        @data.each do |row|
          next if row.length != @columns.length

          @columns.each_with_index do |column, i|
            data_string = column.data_to_s.call(row[i])
            column.width = data_string.length if data_string.length > column.width
          end
        end
      else
        @columns.each { |column| column.width = column.label.length }
      end

      # Print the column headers
      stringio.puts(@columns.collect do |column|
        padding = column.padding || " "
        padding + column.label.center(column.width) + padding
      end.join("|"))

      total_width = stringio.string.length - 1

      # Print the bar below the column header
      stringio.puts(@columns.collect do |column|
        padding = column.padding || " "
        "-" * (column.width + 2 * padding.length)
      end.join("+"))

      # If we have rows, print each one, otherwise print "No rows"
      if @data
        @data.each do |row|
          # Skip rows that have the wrong number of columns
          next if row.length != @columns.length

          # Generate the row of data. These machinations with the index variable are because collect_with_index doesn't exist
          # and Ruby 1.8.x doesn't support each_with_index.collect.
          i = 0
          stringio.puts(row.collect do |data|
            padded_aligned_data = @columns[i].padded_aligned_data(data)
            i += 1
            padded_aligned_data
          end.join("|"))
        end
      else
        stringio.puts("No rows".center(total_width))
      end

      stringio.string
    end


    def to_html(title)
      stringio = StringIO.new

      stringio.puts <<-HTML_HEAD
<!doctype html>
<html>
<head>
  <title>#{title}</title>
  <style type="text/css">
    body
    {
      padding: 10px;
      background-color: white;
      color: black;
      font: 12px Verdana, sans-serif;
      text-rendering: optimizeLegibility;
    }

    table { text-align: center; border: 1px solid #aaa; border-collapse: collapse; width: 100%; }
    td, th { text-align: center; border: 1px solid #aaa; border-collapse: collapse; padding: 2px 5px; }
    th { background-color: #ddd; }
    tbody th { background-color: #eee; font-weight: normal; font-style: italic; }
  </style>
</head>
<body>
  <table>
      HTML_HEAD

      stringio.puts "    <thead>"
      stringio.puts "      <tr>"
      @columns.each { |column| stringio.puts "        <th>#{column.label}</th>" }
      stringio.puts "      </tr>"
      stringio.puts "    </thead>"

      stringio.puts "    <tbody>"
      if @data
        @data.each do |row|
          # Skip rows that have the wrong number of columns
          next if row.length != @columns.length
          stringio.puts "      <tr>"
          row.each_with_index { |data, i| stringio.puts "        <td>#{@columns[i].data_to_s.call(data)}</td>" }
          stringio.puts "      </tr>"
        end
      end

      stringio.puts <<-HTML_FOOT
    </tbody>
  </table>
</body>
</html>
      HTML_FOOT

      stringio.string
    end


    ##
    # Sorts the receiver's data in ascending order using the specified sort keys.
    # +sort_keys+::  A list of column IDs to sort on. If table does not have a column with one of the IDs, that ID is ignored.
    def sort_data_ascending!(*sort_keys)
      self.sort_data!(true, sort_keys)
    end


    ##
    # Sorts the receiver's data in descending order using the specified sort keys.
    # +sort_keys+::  A list of column IDs to sort on. If table does not have a column with one of the IDs, that ID is ignored.
    def sort_data_descending!(*sort_keys)
      self.sort_data!(false, sort_keys)
    end


    ##
    # Sorts the receiver's data using the specified sort order and keys.
    # +is_ascending+:: Whether to sort the data in ascending order or not.
    # +sort_keys+::  A list of column IDs to sort on. If table does not have a column with one of the IDs, that ID is ignored.
    def sort_data!(is_ascending, sort_keys)
      sort_key_indices = sort_keys.collect { |key| @columns.index(@columns.find { |column| column.id == key }) }.reject { |e| !e }

      @data.sort! do |row1, row2|
        comparison_result = 0

        sort_key_indices.each do |index|
          comparison_result = @columns[index].data_comparator.call(row1[index], row2[index])
          comparison_result *= -1 if !is_ascending
          break unless comparison_result == 0
        end

        comparison_result
      end
    end
  end


  ##
  # Instances of Column represent a column of data. Each Column object has an immutable +id+, which should uniquely identify
  # a column within a table. Additionally, each column has a width, label, padding string, alignment, data comparator, and
  # data-to-string conversion procedure.
  class Column
    ##
    # The instance's ID. This ID should be unique across all columns in a Table.
    attr_reader :id

    ##
    # The instance's alignment. Valid values are +:left+, +:center+, and +:right+. Other values will cause incorrect output.
    # Defaults to +:center+.
    attr_accessor :alignment

    ##
    # The procedure used to compare data in the instance. Table objects use this to sort by a column. By default, this is
    # simply:
    #     { |a, b| a <=> b }
    attr_accessor :data_comparator

    ##
    # The procedure used to convert data in the instance to a string. Table objects use this when outputting data. By default,
    # this is simply:
    #     { |o| o.to_s }
    attr_accessor :data_to_s

    ##
    # The column's label. By default, this is the value of +id+.
    attr_accessor :label

    ##
    # The column's padding string. By default, this is +" "+.
    attr_accessor :padding

    ##
    # The column's width as an integer. By default, this is the length of the instance's +label+.
    attr_accessor :width


    ##
    # Initializes a new Column instance with the specified ID and options. Valid keys for options are +:alignment+, +:data_comparator+,
    # +:data_to_s+, +:label+, +:padding+, and +:width+, whose usage should be obvious.
    #
    # +id+::       The new instance's ID.
    # +options+::  An options map specifying zero or more of the column's instance variable values.
    def initialize(id, options = { })
      @id = id

      @alignment = options[:alignment] || :center
      @data_comparator = options[:data_comparator] || Proc.new { |a, b| a <=> b }
      @data_to_s = options[:data_to_s] || Proc.new { |o| o.to_s }
      @label = options[:label] || id
      @padding = options[:padding] || " "
      @width = options[:width] || label.length
    end


    ##
    # Returns a string representation of specified data with the appropriate alignment and padding for the receiver.
    # +data+::  The data to pad and align.
    def padded_aligned_data(data)
      string_repr = @data_to_s.call(data)

      string_repr = case @alignment
      when :left
        string_repr.ljust(@width)
      when :center
        string_repr.center(@width)
      when :right
        string_repr.rjust(@width)
      else
        string_repr
      end

      @padding ? @padding + string_repr + @padding : string_repr
    end
  end
end
