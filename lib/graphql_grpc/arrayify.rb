# typed: true
# MIT License
#
# Copyright (c) 2018, Dane Avilla
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'sorbet-runtime'

module GraphqlGrpc
  #
  # Translate from gRPC hashmaps w/ integer keys to arrays of objects with
  # 'key' and 'value' fields.
  #
  # Recursively descend through the hash; if any hashes are encountered where
  # all the keys are integers, convert that hash into an array of hashes with
  # [{ key: <integer_value>, value: <the_value> },
  #  { key: <integer_value>, value: <the_value> },...]
  #
  # Example: {1: :hello, 2: :world} => [{key:1, value: :hello}, {key:2, value: :world}]
  #
  module Arrayify
    extend T::Sig

    def arrayify_hashes(input)
      case input.class.name.to_sym
      when :Array
        input.map { |i| arrayify_hashes(i) }
      when :Hash
        input_types = input.keys.map(&:class).compact.sort.uniq
        if input_types.inject(true) { |tf, val| val.ancestors.include?(numeric_klass) && tf }
          arr = input.to_a.map { |e| { key: e.first, value: e.last } }
          arrayify_hashes(arr)
        else
          input.each { |k, v| input[k] = arrayify_hashes(v) }
        end
      else
        input
      end
    end

    def numeric_klass
      @numeric_klass ||= begin
        Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.4.0') ? Fixnum : Integer
      end
    end
  end
end
