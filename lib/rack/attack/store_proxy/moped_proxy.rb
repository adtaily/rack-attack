require 'delegate'

module Rack
  class Attack
    module StoreProxy
      class MopedProxy < SimpleDelegator
        def self.handle?(store)
          defined?(::Moped) && store.is_a?(::Moped::Database)
        end

        def initialize(store)
          super(store)
        end

        def read(key)
          result = self[:events].find(
            key: key, expires_in: { :$gt => Time.now }
          ).one

          result["count"] if result
        end

        def write(key, count, options = {})
          to_insert = { key: key, count: count }

          if options[:expires_in]
            to_insert.merge!(expires_in: Time.now + options[:expires_in])
          end

          self[:events].insert(to_insert)
        end

        def increment(key, amount, options = {})
          update_hash = { :$inc => { count: amount } }

          if options[:expires_in]
            update_hash.merge!(
              :$set => { expires_in: Time.now + options[:expires_in] }
            )
          end

          results = self[:events].find(key: key, expires_in: { :$gt => Time.now })

          results.update(update_hash) if results.one

          results.one.fetch("count", nil)
        end

        def delete(key, __options__ = {})
          self[:events].find(key: key).remove
        end
      end
    end
  end
end
