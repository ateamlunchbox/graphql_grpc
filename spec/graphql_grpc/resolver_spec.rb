# MIT License
#
# Copyright (c) 2019, Dane Avilla
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

require 'spec_helper'
require 'graphql_grpc'

RSpec.describe(GraphqlGrpc::Resolver, type: :model) do
  let(:proxy) { double(GraphqlGrpc::Proxy, invoke: nil) }
  let(:resolver) { described_class.new(proxy) }

  let(:field) { OpenStruct.new(name: :foo) }
  let(:obj) do
    o = OpenStruct.new(foo: nil)
    def o.[](n)
      raise TypeError if !n.is_a?(String)
      super(n)
    end
    o
  end
  let(:args) { nil }
  let(:ctx) { nil }

  describe 'When #call-ing a Resolver with a field that is nil' do
    it 'returns nil and does not raise an Exception' do
      expect(resolver.call(nil, field, obj, args, ctx)).to be_nil
    end
  end
end
