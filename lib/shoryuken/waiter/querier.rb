module Shoryuken
  module Waiter
    class Querier
      include Celluloid
      include Util

      def initialize
        delay = Shoryuken::Waiter.poll_delay
        logger.debug { "[Shoryuken::Waiter] Checking for delayed messages every #{delay} seconds" }
        @timer = every(delay) { poll }
      end

      private

      def poll
        Shoryuken::Waiter.tables.each { |table| poll_table(table) }
      end

      def poll_table(table)
        logger.debug { "[Shoryuken::Waiter] Looking for delayed messages in '#{table.table_name}' ready to be queued" }

        query_results(table).each do |response|
          items = response.items
          logger.debug { "[Shoryuken::Waiter] Found #{items.count} delayed messages in '#{table.table_name}'" }
          Shoryuken::Waiter::Enqueuer.enqueue_items(table, items)
        end
      end

      def query_results(table)
        threshold = (Time.now + Shoryuken::Waiter::MAX_QUEUE_DELAY).to_f
        table.query(query_options(threshold))
      end

      def query_options(threshold)
        {
          index_name: "scheduler-perform_at-index",
          select: "SPECIFIC_ATTRIBUTES",
          consistent_read: true,
          projection_expression: [
            "perform_at",
            "sqs_message_body",
            "sqs_message_attributes"
          ].join(","),
          return_consumed_capacity: "NONE",
          key_condition_expression: [
            "#H = :hashval",
            "#R < :rangeval"
          ].join(" AND "),
          expression_attribute_names: {
            "#H": "scheduler",
            "#R": "perform_at"
          },
          expression_attribute_values: {
            ":hashval": Shoryuken::Waiter::TABLE_PRIMARY_ITEM_KEY_VALUE,
            ":rangeval": threshold
          }
        }
      end
    end
  end
end
