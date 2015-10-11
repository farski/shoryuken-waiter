require "celluloid"
require "aws-sdk-resources"
require "shoryuken"
require "shoryuken/waiter/version"
require "shoryuken/waiter/enqueuer"
require "shoryuken/waiter/querier"

module Shoryuken
  module Waiter
    MAX_QUEUE_DELAY = 15 * 60
    DEFAULT_POLL_DELAY = 5 * 60
    TABLE_PRIMARY_ITEM_KEY_VALUE = "shoryuken-waiter"

    class << self
      def client
        @client ||= Aws::DynamoDB::Client.new
      end

      def tables
        @tables ||= Shoryuken.queues.uniq.map do |queue_name|
          table = Aws::DynamoDB::Table.new(queue_name, client: client)

          begin
            table.table_arn
            Shoryuken.logger.debug { "[Shoryuken::Waiter] Found wait table for queue '#{queue_name}'" }
            table
          rescue Aws::DynamoDB::Errors::ResourceNotFoundException
            Shoryuken.logger.debug { "[Shoryuken::Waiter] No wait table for queue '#{queue_name}'" }
            nil
          end
        end.compact
      end

      def options
        @options ||= Shoryuken.options[:waiter] || {}
      end

      def poll_delay
        options[:delay] || DEFAULT_POLL_DELAY
      end
    end
  end
end

require "shoryuken/waiter/extensions/active_job_adapter" if defined? ::ActiveJob

Shoryuken.configure_server do |config|
  config.on(:startup) do
    tables = Shoryuken::Waiter.tables
    queues = Shoryuken.queues.uniq
    Shoryuken.logger.info { "[Shoryuken::Waiter] Starting. Polling #{tables.count} tables for #{queues.count} queues" }
    Shoryuken::Waiter::Querier.supervise_as :shoryuken_waiter_querier
  end
end
