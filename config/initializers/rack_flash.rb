module Rack

  class Flash

    class SessionUnavailable < StandardError; end

    class FlashHash

      def initialize(store)
        raise Rack::Flash::SessionUnavailable \
          .new('Rack::Flash depends on session middleware.') unless store
        @store = store
      end

      def [](key)
        key = key.to_sym
        cache[key] ||= values.delete(key)
      end

      def []=(key,val)
        key = key.to_sym
        cache[key] = values[key] = val
      end

      def now
        cache
      end

      def has?(key)
        [cache, values].any? { |store| store.keys.include?(key.to_sym) }
      end
      alias_method :include?, :has?

      def keys
        cache.keys | values.keys
      end

      def inspect
        'Flash'
      end

      def to_s
        values.inspect
      end

      private

      def cache
        @cache ||= {}
      end

      def values
        @store[:__FLASH__] ||= {}
      end

      def def_accessor(key)
        raise ArgumentError.new('Invalid entry type: %s' % key) if respond_to?(key)

        class << self; self end.class_eval do
          define_method(key) { |*args| val = args.first; val ? (self[key]=val) : self[key] }
          define_method("#{key}=") { |val| self[key] = val }
          define_method("#{key}!") { |val| cache[key] = val }
        end
      end
    end

  end
end

def flash
  env['x-rack.flash'] ||= Rack::Flash::FlashHash.new(env['rack.session'])
end