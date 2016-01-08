require 'delegate'

module Rack
  class Attack
    module StoreProxy
      class MongoDbProxy < SimpleDelegator
        def self.handle?(store)
          defined?(::Mongo) && store.is_a?(::Mongo::Client)
        end

        def initialize(store)
          super(store)
        end

        def read(key)
          result = self[:events].find(key: key).limit(1).first
          result["value"] if result
        end

        def write(key, value, options = {})
          to_insert = { key: key, value: value }

          if options[:expires_in]
            to_insert.merge!(expires_in: Time.now + options[:expires_in])
          end

          self[:events].insert_one(to_insert)
        end

        def increment(key, amount, options = {})
          count = nil

          collection = self[:events].find(key: key)
          changed = collection.update_one(:$inc => { count: amount }).n
          count = collection.first.count unless changed.zero?

          if options[:expires_in]
            collection.update_one(
              :$set => { expires_in: Time.now + options[:expires_in] }
            )
          end

          count
        end

        def delete(key, options = {})
          self[:events].find(key: key).delete_one
        end
      end
    end
  end
end
