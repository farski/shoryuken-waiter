require "shoryuken-waiter"
require "shoryuken/extensions/active_job_adapter"
require "securerandom"

module ActiveJob
  module QueueAdapters
    # == Shoryuken::Waiter adapter for Active Job
    #
    # Shoryuken ("sho-ryu-ken") is a super-efficient AWS SQS thread based
    # message processor.
    # Shoryuken::Waiter allows messages to be delayed arbitrarily far into the
    # future, which is not possible with Shoryuken on its own, as it is limited
    # by SQS's 15 minute maximum delay.
    #
    # Read more about Shoryuken {here}[https://github.com/phstc/shoryuken].
    # Read more about Shoryuken::Waiter {here}[https://github.com/farski/shoryuken-waiter].
    #
    # To use Shoryuken::Waiter set the queue_adapter config to +:shoryuken_waiter+.
    #
    #   Rails.application.config.active_job.queue_adapter = :shoryuken_waiter
    class ShoryukenWaiterAdapter < ShoryukenAdapter
      JobWrapper = ShoryukenAdapter::JobWrapper

      class << self
        def enqueue_at(job, timestamp) #:nodoc:
          delay = (timestamp - Time.current.to_f).round

          tables = Shoryuken::Waiter.tables
          # TODO Make this not have to #detect every time
          table = tables.detect { |t| t.table_name == job.queue_name }

          if delay > 15.minutes && table
            register_worker!(job)
            delay_enqueue_at(table, job, timestamp)
          else
            super(job, timestamp)
          end
        end

        private

        def message_attributes
          @message_attributes ||= {
            "shoryuken_class" => {
              string_value: JobWrapper.to_s,
              data_type: "String"
            }
          }
        end

        def item(job, timestamp)
          {
            scheduler: Shoryuken::Waiter::TABLE_PRIMARY_ITEM_KEY_VALUE,
            job_id: job.serialize["job_id"],
            perform_at: timestamp,
            sqs_message_body: job.serialize,
            sqs_message_attributes: message_attributes
          }
        end

        def delay_enqueue_at(table, job, timestamp) #:nodoc:
          # TODO Do something if the put fails
          # TODO Figure out the conditional put to ensure uniqueness
          # logger.debug { "[Shoryuken::Waiter] Delayed message tables query delay: #{delay}" }
          table.put_item(
            item: item(job, timestamp),
            return_values: "NONE",
            return_consumed_capacity: "NONE",
            return_item_collection_metrics: "NONE"
          )
        end
      end
    end
  end
end
