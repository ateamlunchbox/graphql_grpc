module GraphqlGrpc
  class Resolver
    def initialize(proxy)
      @proxy = proxy
    end

    attr_reader :proxy

    def call(_type, field, obj, args, ctx)
      if obj
        field_sym = field.name.to_sym
        # Try to access the field as a method, then with Hash notation using
        # a Symbol and finally as a String.

        value = if obj.is_a?(Hash)
          # Prefer Hash value over method in case Hash keys conflict
          # with method names on Hash.
          obj[field_sym] || obj.try(field_sym)
        else
          obj[field_sym.to_s]
        end
        return value.is_a?(Symbol) ? value.to_s : value
      end
      proxy.invoke(field, args, ctx)
    end
  end
end
