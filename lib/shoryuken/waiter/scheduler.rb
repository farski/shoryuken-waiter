module Shoryuken
  module Waiter
    class Scheduler
      class << self
        include Util

        # TODO If there is ever support for tables that don't map 1:1 to queues,
        # a query may return items intended for many queues, so in order to be
        # able to batch then with #send_messages, the would need to be sorted
        #
        # TODO If the actor were to crash in the middle of a batch, messages
        # could get lost
        def schedule_items(table, items)
          return if items.empty?

          queue_name = items.first["sqs_message_body"]["queue_name"]
          queue = Shoryuken::Client.queues(queue_name)

          send_messages(queue, items.map { |item| message(table, item) })
        end

        private

        def message(table, item)
          if item_deleted?(table, item)
            # TODO Only return the message if it has all the parts it needs
            {
              message_body: item["sqs_message_body"],
              delay_seconds: (Time.at(item["perform_at"]) - Time.now).to_i,
              message_attributes: item["sqs_message_attributes"].map do |k, v|
                [k, (v.map { |_k, _v| [_k.to_sym, _v] }.to_h)]
              end.to_h
            }
          end
        end

        def send_messages(queue, messages)
          messages.compact.each_slice(10) do |batch|
            logger.info { "[Shoryuken::Waiter] Queueing #{batch.count} delayed messages to '#{queue.name}'" }
            queue.send_messages(batch)
          end
        end

        def item_deleted?(table, item)
          delete_item(table, item)
          logger.debug { "[Shoryuken::Waiter] Deleting 1 delayed message from '#{table.table_name}'" }
          return true
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
          return false
        end

        # TODO Maybe use BatchWriteItem to delete many items at once
        def delete_item(table, item)
          table.delete_item(
            key: {
              "scheduler": Shoryuken::Waiter::TABLE_PRIMARY_ITEM_KEY_VALUE,
              "job_id": item["sqs_message_body"]["job_id"]
            },
            return_values: "NONE",
            return_consumed_capacity: "NONE",
            return_item_collection_metrics: "NONE"
          )
        end
      end
    end
  end
end
