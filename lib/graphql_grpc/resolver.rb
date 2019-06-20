module GraphqlGrpc
  class Resolver
    def initialize(proxy)
      @proxy = proxy
    end

    attr_reader :proxy

    def call(_type, field, obj, args, ctx)
      if obj
        field_sym = field.name.to_sym
        value = obj.try(field_sym) || obj[field_sym.to_s] || begin
          obj[field_sym]
        rescue TypeError => e
          nil
        end
        return value.is_a?(Symbol) ? value.to_s : value
      end
      proxy.invoke(field, args, ctx)
    end
  end
end
