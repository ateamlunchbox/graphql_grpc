module GraphqlGrpc
  class Resolver
    def initialize(proxy)
      @proxy = proxy
    end

    attr_reader :proxy

    def call(_type, field, obj, args, ctx)
      if obj
        value = obj[field.name.to_sym]
        return value.is_a?(Symbol) ? value.to_s : value
      end
      proxy.invoke(field, args, ctx)
    end
  end
end
